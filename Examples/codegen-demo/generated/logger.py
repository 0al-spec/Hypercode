# GENERATED from the Hypercode resolved graph — do not edit by hand.
# Regenerate with ../generate.sh when check.py reports this module stale.
# node: /Service/Logger
# hash: 67f124e133a8b12970f02c154195f4ea9b176e137360ed6e37dbd88645fa4289
# context: env=production

CONFIG = {
    "level": "info",    # Logger @ Examples/service.hcs:16
    "format": "json",   # .console @ Examples/service.hcs:19
}

LEVELS = ("debug", "info", "warning", "error")


class Logger:
    """Console logger (class: console) for the Service node tree."""

    def __init__(self):
        self.level = CONFIG["level"]
        self.format = CONFIG["format"]

    def log(self, level, message):
        if LEVELS.index(level) < LEVELS.index(self.level):
            return None
        if self.format == "json":
            import json
            return json.dumps({"level": level, "message": message})
        return f"[{level}] {message}"
