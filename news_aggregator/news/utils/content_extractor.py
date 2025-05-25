import requests
from bs4 import BeautifulSoup
import re
from html import unescape

DEFAULT_IMAGE_URL = 'https://raw.githubusercontent.com/mMelnic/news-fake-detection/refs/heads/users/news_aggregator/newspaper_beige.jpg'
MIN_CONTENT_WORDS = 100
MAX_CONTENT_WORDS = 500

class ContentExtractor:

    def get_article_content(self, url, title):
        """Get clean text content from article paragraphs"""
        try:
            headers = {'User-Agent': 'Mozilla/5.0'}
            response = requests.get(url, headers=headers, timeout=10)
            soup = BeautifulSoup(response.text, 'html.parser')

            # Extract good paragraphs only
            paragraphs = self.extract_clean_paragraphs(soup, title)

            if not paragraphs:
                return None

            full_content = '\n\n'.join(paragraphs)
            words = full_content.split()[:MAX_CONTENT_WORDS]
            truncated = ' '.join(words)
            if len(words) == MAX_CONTENT_WORDS:
                truncated += " [...]"

            return {
                'full_content': full_content,
                'truncated_content': truncated,
                'word_count': len(full_content.split()),
                'paragraph_count': len(paragraphs)
            }

        except Exception as e:
            print(f"Error scraping {url}: {e}")
            return None

    def extract_clean_paragraphs(self, soup, title):
        """Extract only meaningful <p> tag content"""
        paragraphs = []

        for p in soup.find_all('p'):
            text = p.get_text(strip=True)
            if self.is_article_content(text, title):
                clean_text = re.sub(r'\s+', ' ', text).strip()
                paragraphs.append(clean_text)

        return paragraphs

    def is_article_content(self, text, title, min_words=MIN_CONTENT_WORDS):
        """Check if text is meaningful article content"""
        text = text.strip()

        if len(text.split()) < min_words:
            return False

        boilerplate_phrases = [
            'cookie policy', 'privacy policy', 'terms of use',
            'all rights reserved', '©', 'sign up for our newsletter',
            'related articles', 'continue reading', 'click here',
            'published on', 'last updated', 'photo credit',
            'please share', 'follow us', 'comments', 'cookies'
        ]

        if any(phrase.lower() in text.lower() for phrase in boilerplate_phrases):
            return False

        if title.lower() in text.lower():
            return False

        if len(text) < 60 and (text.endswith('.') or text.endswith(':')):
            return False

        return True

    def get_article_image(self, entry):
        """Universal image extractor from entry metadata and content"""
        # 1. media_content
        if hasattr(entry, 'media_content') and entry.media_content:
            for media in entry.media_content:
                if media.get('medium') == 'image':
                    return media['url']

        # 2. media_thumbnail
        if hasattr(entry, 'media_thumbnail') and entry.media_thumbnail:
            return entry.media_thumbnail[0]['url']

        # 3. enclosures
        if hasattr(entry, 'enclosures') and entry.enclosures:
            for enc in entry.enclosures:
                if enc.get('type', '').startswith('image/'):
                    return enc['href']

        # 4. description fallback
        if hasattr(entry, 'description'):
            soup = BeautifulSoup(entry.description, 'html.parser')
            img = soup.find('img')
            if img and img.get('src'):
                return img['src']

        return DEFAULT_IMAGE_URL