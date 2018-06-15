#!/usr/bin/env python
# -*- coding:utf-8 -*-

import redis
from config import config


def get_pool(db=0):
    pool = redis.ConnectionPool(host=config["redis"]["host"],
            port=config["redis"]["port"],
            password = config["redis"]["password"],
            db=db)
    return pool

def redis_connect(db=0, pool=None):
    if not pool:
        pool = get_pool(db)
    return redis.Redis(connection_pool=pool)

r_client = redis_connect()
