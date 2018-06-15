#!/usr/bin/env python
# -*- coding:utf-8 -*-

import sys
import os

settings_path = os.path.dirname(os.path.abspath(__file__))
project_path = os.path.dirname(settings_path)
print(project_path)
sys.path.append(project_path)

from models.base import *
from models.tables import *
from os.path import dirname

def main():
    try:
        # 删除所有表
        drop_all_table()
        # 创建所有表
        create_all_table()
    except Exception as e:
        print("init qdata_cloud error: {}".format(e))


def test():
    session = Session()
    c = session.query(Contract).filter(Contract.address == "0xC332b3E7aeB6cE90b0713f51FE9FB10459136F7E").one()
    import pdb; pdb.set_trace()
    print(c)

if __name__ == "__main__":
    main()
