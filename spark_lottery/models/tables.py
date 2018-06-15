#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
from datetime import datetime
from models.base import MutableDict, metadata, engine
from sqlalchemy.orm import relationship, backref
from models.base import Entity, Session, open_session
from sqlalchemy import Column, Integer, String, Text, PickleType, Float, DateTime, ForeignKey, Boolean


class Players(Entity):
    __tablename__ = "players"

    player_address = Column(String(length=100), nullable=False)
    round = Column(Integer, nullable = False)
    is_winner = Column(Boolean, default=False, nullable = False)
    bouners = Column(String(length=10), default=0.0)
    contract_address = Column(String(length=100), nullable = False)

class Contract(Entity):
    __tablename__ = "contract"
    name = Column(String(length=100), nullable=False)
    address = Column(String(length=100), nullable=False)
    balance = Column(Integer, nullable=True)
    current_round = Column(Integer, default=1)

metadata.create_all(engine)
