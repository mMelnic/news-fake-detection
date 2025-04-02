import torch

def multitask_collate_fn(batch):
    """
    Custom collate function to handle multi-task batching.
    Ensures each batch retains its task identity.
    """
    batch_dict = {"input_ids": [], "attention_mask": [], "labels": [], "tasks": []}
    
    for sample in batch:
        batch_dict["input_ids"].append(torch.tensor(sample["input_ids"]))
        batch_dict["attention_mask"].append(torch.tensor(sample["attention_mask"]))
        batch_dict["labels"].append(sample["label"])
        batch_dict["tasks"].append(sample["task"])
    
    batch_dict["input_ids"] = torch.stack(batch_dict["input_ids"])
    batch_dict["attention_mask"] = torch.stack(batch_dict["attention_mask"])
    batch_dict["labels"] = torch.tensor(batch_dict["labels"], dtype=torch.long)
    
    return batch_dict

