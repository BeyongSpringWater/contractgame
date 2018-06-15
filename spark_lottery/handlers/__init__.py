#!/usr/bin/env python
# -*- coding: utf-8 -*-

import traceback
import hashlib
import sys
import functools
import urllib
import json
import logging
from sqlalchemy import text
from tornado import escape
from tornado.options import options
from tornado.concurrent import run_on_executor
from tornado.web import RequestHandler
from tornado.web import Finish
from tornado.web import MissingArgumentError
from tornado.log import access_log
from concurrent.futures import ThreadPoolExecutor
from models.base import Session
from schema import SchemaError, Use, Or, And
from tornado.escape import utf8

UTF8 = And(Or(Use(utf8), Use(str)), len)     # 非空
UTF8_none = Or(Use(utf8), Use(str))
COOKIE_USER = "login_user_id"


class BaseRequestHandler(RequestHandler):
    """Base RequestHandler"""

    # thread pool executor
    executor = ThreadPoolExecutor(30)

    def get_current_user(self):
        try:
            data = self.get_secure_cookie(COOKIE_USER)
            return json.loads(data)
        except:
            return None

    # @property
    # def redis(self):
        # """Return redis connection"""
        # return self.application.redis

    def prepare(self):
        """prepare is called when the request headers have been read instead of after
        the entire body has been read.
        """
        self.do_prepare()

    def do_prepare(self, *args, **kwargs):
        pass

    def get_session(self):
        self.session = Session()

    def on_finish(self):
        self.do_finish()

    def do_finish(self, *args, **kwargs):
        pass

    def _param_json_decode(self, value):
        try:
            value = json.loads(value)
            return value
        except Exception as e:
            logging.exception(e)
            self.error_response("parse json error: {}".format(value))

    def get_url_data(self):
        """
        返回get请求的数据
        获取query_arguments，同一key有重复值时只取值列表最后一个
        """
        return {key: value[-1] for key, value in self.request.query_arguments.items()}

    def get_body_data(self, name=None):
        """
        当post时，获取json数据
        """
        try:
            if name:
                data = json.loads(self.get_body_argument(name))
            else:
                data = json.loads(self.request.body)
            return data
        except ValueError as e:
            logging.exception(e)
            self.error_response(1, message="get json in body error: {}".format(e.message))

    def get_data(self, schema=None):
        """
        post, get, put, delete 类型handler 验证数据,
        schema 是 from schema import Schema中的Schema的一个实例
        func_type: get, post, put, delete
        """
        stack = traceback.extract_stack()
        func_type = stack[-2][2]
        if func_type in ["post", "put", "delete"]:
            data = self.get_body_data()
        elif func_type == "get":
            data = self.get_url_data()
        else:
            raise Exception("unsurported function type: {}".format(func_type))
        try:
            if schema:
                data = schema.validate(data)
            return data
        except SchemaError as e:
            logging.exception(e)
            code = 1
            # code 中文错误信息要先进行编码转换
            code_message = "xxx"
            error_message = "{}: {}".format(code_message, e.message)
            self.error_response(error_code=code, message=error_message)

    def write_json(self, data):
        self.set_header("Content-Type", "application/json")
        if options.debug:
            self.write(json.dumps(data, indent=2))
        else:
            self.write(json.dumps(data))

    def success_response(self, data=None, message="", finish=True):
        response = {
            "error_code": 0,
            "message": message,
            "data": data
        }
        self.write_json(response)
        if finish:
            raise Finish

    def error_response(self, error_code, message="", format_str="", data=None, status_code=200, finish=True):
        self.set_status(200)
        if not message:
            message = "internal error"
        if format_str:
            message = message.format(format_str)
        response = {
            "error_code": error_code,
            "data": data,
            "message": message,
        }
        self.write_json(response)
        if finish:
            raise Finish

    @run_on_executor()
    def run_sql(self, sql_string, **kwargs):
        sql = text(sql_string)
        result = self.session.execute(sql, kwargs).fetchall()
        return result

    def options(self, *args, **kwargs):
        """
        避免前端跨域options请求报错
        """
        self.set_header("Access-Control-Allow-Origin", "*")
        self.set_header("Access-Control-Allow-Methods",
                        "POST, GET, PUT, DELETE, OPTIONS")
        self.set_header("Access-Control-Max-Age", 1000)
        self.set_header("Access-Control-Allow-Headers",
                        "CONTENT-TYPE, Access-Control-Allow-Origin, x-access-token")
        self.set_header("Access-Control-Expose-Headers", "X-Resource-Count")

    def set_default_headers(self):
        self.set_header("Access-Control-Allow-Origin", "*")
        self.set_header("Access-Control-Allow-Methods",
                        "POST, GET, PUT, DELETE, OPTIONS")
        self.set_header("Access-Control-Max-Age", 1000)
        self.set_header("Access-Control-Allow-Headers",
                        "CONTENT-TYPE, Access-Control-Allow-Origin, x-access-token")
        self.set_header("Access-Control-Expose-Headers", "X-Resource-Count")


class ApiHandler(BaseRequestHandler):

    def get_current_user(self):
        user_cookie = self.get_secure_cookie(COOKIE_USER)
        if not user_cookie:
            return None
        else:
            return escape.json_decode(user_cookie)

    def do_prepare(self):
        self.get_session()
        if self.request.headers.get("Content-Type", "").startswith("application/json"):
            try:
                self.json_args = json.loads(self.request.body)
            except ValueError:
                self.json_args = {}
        else:
            self.json_args = {}

    def do_finish(self):
        try:
            self.session.close()
        except AttributeError:
            logging.info("no session to close")
        except Exception as e:
            logging.exception(e)

    def check_get_data(self, data):
        pass

    def check_post_data(self, data):
        pass

    def set_resource_count(self, count):
        """
        Pagination requirement
        """
        self.set_header("X-Resource-Count", count)

    @property
    def pagination_params(self):
        """获取分页参数
        """
        try:
            page = int(self.get_argument("page", 1))
            count = int(self.get_argument("count", 20))
        except ValueError:
            self.error_response(1)
        page = 1 if page < 1 else page
        count = 20 if count < 1 else count
        offset = (page - 1) * count

        return page, count, offset
