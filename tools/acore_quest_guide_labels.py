"""Preserve an English guide label and its name references for localization."""


def describe_guide(pattern, *entities):
    """Each entity supplies its kind, ID and source template."""
    names = tuple(str(template.get("name") or entry) for _, entry, template in entities)
    references = [[kind, entry] for kind, entry, _ in entities]
    return {3: pattern % names, 6: [pattern, *references]}
