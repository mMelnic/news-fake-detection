import os
import xml.etree.ElementTree as ET
from django.core.management.base import BaseCommand
from django.db import transaction
from urllib.parse import urlparse
from news.models import Feed, Sources
import requests
import feedparser
from datetime import datetime
import pycountry
from html import unescape
import re

class Command(BaseCommand):
    help = 'Import RSS feeds from OPML files with proper category/country handling'

    def add_arguments(self, parser):
        parser.add_argument('--dir', type=str, help='Directory containing OPML files')

    def handle(self, *args, **options):
        opml_dir = options['dir']
        if not opml_dir:
            self.stderr.write(self.style.ERROR('Please specify --dir parameter'))
            return

        self.process_opml_directory(opml_dir)

    def process_opml_directory(self, directory):
        for filename in os.listdir(directory):
            if filename.endswith('.opml'):
                filepath = os.path.join(directory, filename)
                dir_name = os.path.basename(os.path.normpath(directory)).lower()
                self.stdout.write(f"Processing {filename}...")
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        try:
                            content = f.read()
                        except UnicodeDecodeError:
                            with open(filepath, 'r', encoding='latin-1') as f2:
                                content = f2.read()
                    
                    content = self.clean_xml(content)
                    parser = ET.XMLParser(encoding='utf-8')
                    tree = ET.ElementTree(ET.fromstring(content, parser=parser))
                    root = tree.getroot()
                    
                    is_country = dir_name == 'country'
                    
                    # Get all parent outlines (categories/countries)
                    for parent_outline in root.findall('.//body/outline'):
                        category_or_country = parent_outline.attrib.get('text', '').lower()
                        
                        # Process each feed within this category/country
                        for feed_outline in parent_outline.findall('outline'):
                            self.process_feed(feed_outline, is_country, category_or_country)
                        
                except ET.ParseError as e:
                    self.stderr.write(self.style.ERROR(f"XML parse error in {filename}: {e}"))
                except Exception as e:
                    self.stderr.write(self.style.ERROR(f"Error processing {filename}: {e}"))

    def process_feed(self, outline, is_country, category_or_country):
        feed_url = outline.attrib.get('xmlUrl')
        if not feed_url:
            return

        feed_info = self.get_feed_info(feed_url)
        if not feed_info or not feed_info.get('valid'):
            self.stdout.write(self.style.WARNING(f"Skipping invalid/empty feed: {feed_url}"))
            return

        with transaction.atomic():
            domain = urlparse(feed_url).netloc
            
            # Determine country/category values
            if is_country:
                country_code = self.get_country_code(category_or_country)
                category = None
            else:
                country_code = None
                category = category_or_country

            source, created = Sources.objects.get_or_create(
                url=f"https://{domain}",
                defaults={
                    'name': outline.attrib.get('title', domain),
                    'country': country_code,
                    'language': feed_info.get('language_code')
                }
            )

            feed, created = Feed.objects.update_or_create(
                url=feed_url,
                defaults={
                    'title': feed_info.get('title') or outline.attrib.get('title', ''),
                    'description': feed_info.get('description') or outline.attrib.get('description', ''),
                    'source': source,
                    'country': country_code,
                    'category': category,
                    'language': feed_info.get('language_code'),
                    'last_built': feed_info.get('last_built'),
                    'is_active': True
                }
            )

            if created:
                self.stdout.write(self.style.SUCCESS(f"Added new feed: {feed_url}"))
            else:
                self.stdout.write(f"Updated existing feed: {feed_url}")

    def escape_unescaped_ampersands(self, text):
        # Replace & not followed by one of: amp;, lt;, gt;, quot;, apos;, #digits; or #xhex;
        pattern = re.compile(r'&(?!([a-zA-Z]+|#\d+|#x[\da-fA-F]+);)')
        return pattern.sub('&amp;', text)
    
    def clean_xml(self, content):
        """Handle common XML issues"""
        if content.startswith('\ufeff'):
            content = content[1:]
        content = unescape(content)
        content = self.escape_unescaped_ampersands(content)
        content = ''.join(char for char in content if ord(char) >= 32 or char in '\t\n\r')
        return content

    def get_feed_info(self, feed_url):
        try:
            feed = feedparser.parse(feed_url)
            
            if getattr(feed, 'bozo', False) or not feed.entries:
                return {'valid': False}
            
            language_code = feed.feed.get('language', '').lower().split('-')[0]
            
            last_built = None
            if hasattr(feed.feed, 'updated_parsed'):
                last_built = datetime(*feed.feed.updated_parsed[:6])
            elif hasattr(feed.feed, 'published_parsed'):
                last_built = datetime(*feed.feed.published_parsed[:6])
            
            return {
                'valid': True,
                'title': feed.feed.get('title', ''),
                'description': feed.feed.get('description', ''),
                'language_code': language_code,
                'last_built': last_built,
                'entry_count': len(feed.entries)
            }
            
        except Exception as e:
            self.stdout.write(self.style.WARNING(f"Error processing feed {feed_url}: {str(e)}"))
            return {'valid': False}

    def get_country_code(self, country_name):
        if not country_name:
            return None
            
        try:
            country = pycountry.countries.get(name=country_name)
            if country:
                return country.alpha_2.lower()
            
            country = pycountry.countries.search_fuzzy(country_name)[0]
            return country.alpha_2.lower()
        except:
            return None

    def validate_feed_url(self, url):
        try:
            response = requests.get(url, timeout=10)
            if response.status_code != 200:
                return False
                
            content = response.text.lower()
            return ('<rss' in content) or ('<feed' in content) or ('xmlns:atom' in content)
        except:
            return False
