# GENERATED from the Hypercode resolved graph — do not edit by hand.
# Regenerate with ../generate.sh when check.py reports this module stale.
# node: /Service/APIServer
# hash: 7da0acd4b1617ed3a2e3ce7af9c3b5cbdd33e5d8ba7427bee2bfbb869da5101a
# context: env=production

CONFIG = {
    "host": "0.0.0.0",    # APIServer > Listen @ Examples/service.hcs:26
    "port": 8080,         # APIServer > Listen @ Examples/service.hcs:26
}


class APIServer:
    """API server with its Listen child node."""

    def __init__(self, logger, database):
        self.logger = logger
        self.database = database
        self.host = CONFIG["host"]
        self.port = CONFIG["port"]

    def listen(self):
        # child node: /Service/APIServer/Listen
        self.logger.log("info", f"listening on {self.host}:{self.port}")
        return (self.host, self.port)
