#!/usr/bin/env python
# -*- coding: utf-8 -*-
import json
from config import config
from datetime import datetime
from sqlalchemy import inspect
from sqlalchemy import Column, Integer, String, Text, PickleType, DateTime
from sqlalchemy.ext.mutable import Mutable
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.orm.attributes import flag_modified
from sqlalchemy.schema import MetaData
from contextlib import contextmanager


engine_str =  config["sqlite_db"]
engine = create_engine(engine_str, encoding='utf8', convert_unicode=True)
Session = sessionmaker(bind=engine, autocommit=True,
                       autoflush=False, expire_on_commit=False)
metadata = MetaData(bind=engine)
g_session = Session()


class MutableDict(Mutable, dict):

    @classmethod
    def coerce(cls, key, value):
        if not isinstance(value, MutableDict):
            if isinstance(value, dict):
                return MutableDict(value)
            return Mutable.coerce(key, value)
        else:
            return value

    def __delitem(self, key):
        dict.__delitem__(self, key)
        self.changed()

    def __setitem__(self, key, value):
        dict.__setitem__(self, key, value)
        self.changed()

    def __getstate__(self):
        return dict(self)

    def __setstate__(self, state):
        self.update(self)


class ModelMixin(object):
    """
    自带两个时间戳字段的base model
    """

    id = Column(Integer, primary_key=True, autoincrement=True, nullable=False)

    def __getitem__(self, key):
        return getattr(self, key)

    def __getattribute__(self, key):
        return super(ModelMixin, self).__getattribute__(key)

    @classmethod
    def get_first(cls, key, value, session=None):
        if not session:
            session = g_session
        obj = session.query(cls).filter(getattr(cls, key) == value).first()
        return obj

    @classmethod
    def get_one(cls, key, value, session=None):
        if not session:
            session = g_session
        obj = session.query(cls).filter(getattr(cls, key) == value).one()
        return obj

    @classmethod
    def get_all(cls, key=None, value=None, session=None):
        if not session:
            session = g_session
        if key:
            objs = session.query(cls).filter(getattr(cls, key) == value).all()
        else:
            objs = session.query(cls).all()
        return objs

    @classmethod
    def merge(cls, obj, key=None, value=None, session=None):
        """
        用返回值来区分更新还是插入
        """
        if not session:
            session = g_session
        if not key or not value:
            session.merge(obj)
        else:
            old_obj = cls.get_first(key, value, session)
            if old_obj:
                obj.id = old_obj.id
                obj.update_time = datetime.utcnow()
                session.merge(obj)
            else:
                session.add(obj)
        try:
            session.flush()
        except Exception as e:
            session.rollback()
            raise e

    def to_dict(self):
        """返回一个dict格式"""
        result = {}
        columns = self.__table__.columns.keys()
        for column in columns:
            result[column] = getattr(self, column)
        return result

    @property
    def info(self):
        info = self.to_dict()
        result = {}
        for key, value in info.iteritems():
            if isinstance(value, datetime):
                result[key] = value.strftime("%Y-%m-%d %H:%M")
            else:
                result[key] = value
        return result


    def update_parameter(self, parameter, session=None):
        if not session:
            session = Session()
        self.parameter = parameter
        flag_modified(self, "attr")
        session.merge(self)
        try:
            session.flush()
        except Exception as e:
            session.rollback()
            raise e

    def save(self, session=None):
        if not session:
            session = g_session
        self.update_time = datetime.utcnow()
        flag_modified(self, "attr")
        session.merge(self)
        try:
            session.flush()
        except Exception as e:
            raise e

    @classmethod
    def initialize(cls):
        """删除表并创建表"""
        table_name = cls.__table__.name
        try:
            table = metadata.tables[table_name]
        except KeyError:
            return False
        try:
            metadata.drop_all(tables=[table])
            metadata.create_all(tables=[table])
        except Exception:
            return False
        return True

    @classmethod
    def table_columns(cls):
        """ 得到表的字段 """
        return inspect(cls).columns.keys()

    @classmethod
    def drop_table(cls):
        """删除表"""
        if cls.__table__ in metadata.sorted_tables:
            cls.__table__.drop(engine)


@contextmanager
def open_session():
    """ 可以使用with 上下文，在with结束之后自动commit """
    session = Session()
    session.begin()
    try:
        yield session
        session.commit()
    except Exception as e:
        session.rollback()
        raise e
    finally:
        session.close()


def get_new_session():
    """返回一个新session"""
    try:
        new_session = Session()
        return new_session
    except:
        return None


def clean_all_table():
    """ 清除所有的表 """
    metadata.drop_all(engine)
    metadata.create_all(engine)


def drop_all_table():
    """ 删除所有的表 """
    metadata.drop_all(engine)


# create table
def create_all_table():
    metadata.create_all(checkfirst=True)

Entity = declarative_base(name="Entity", metadata=metadata, cls=ModelMixin)
