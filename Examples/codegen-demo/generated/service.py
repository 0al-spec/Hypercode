# GENERATED from the Hypercode resolved graph — do not edit by hand.
# Regenerate with ../generate.sh when check.py reports this module stale.
# node: /Service
# hash: d476920df7d813dd3e422bc04ee8f2926624f2f21737bee37c3315e277fe96b1
# context: env=production
#
# This is the wiring module: it instantiates children in .hc document order.
# Its node hash covers the whole subtree (Merkle), so any change anywhere in
# the resolved graph marks the wiring stale too.

CONFIG = {}

from logger import Logger
from database import Database
from api_server import APIServer


def build_service():
    """Wire the Service tree: Logger.console, Database#main-db, APIServer."""
    logger = Logger()
    database = Database()
    database.connect()
    server = APIServer(logger, database)
    return server


if __name__ == "__main__":
    server = build_service()
    print(server.listen())
