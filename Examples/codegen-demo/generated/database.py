# GENERATED from the Hypercode resolved graph — do not edit by hand.
# Regenerate with ../generate.sh when check.py reports this module stale.
# node: /Service/Database#main-db
# hash: baf7d11c1bf41439b03c0c82a62211465d47d43d84c769e0b702d1383e8c8243
# context: env=production

CONFIG = {
    "driver": "postgres",     # '#main-db' @ Examples/service.hcs:22
    "file": "dev.sqlite3",    # Database @ Examples/service.hcs:7 (not overridden in production)
    "pool_size": 50,          # '#main-db' @ Examples/service.hcs:22
}


class Database:
    """Database #main-db with its Connect child node."""

    def __init__(self):
        self.driver = CONFIG["driver"]
        self.pool_size = CONFIG["pool_size"]
        self._pool = []

    def connect(self):
        # child node: /Service/Database#main-db/Connect
        self._pool = [f"{self.driver}-conn-{i}" for i in range(self.pool_size)]
        return len(self._pool)
