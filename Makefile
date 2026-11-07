# OPPO 电视（OPPOCNM632）常用操作
# 用法：make <target> [ARGS="..."]

ARGS ?=

.PHONY: help list check apply restore fetch-apks

help:
	@echo "make list                  查看精简清单"
	@echo "make check  [ARGS=...]     只读检查电视"
	@echo "make apply  [ARGS=...]     执行精简（自动备份）"
	@echo "make restore [ARGS=...]    回滚（ARGS 可传备份名）"
	@echo "make fetch-apks            下载备用 APK 并校验"
	@echo ""
	@echo "示例："
	@echo "  make check ARGS=\"--connect 192.168.1.20\""
	@echo "  make restore ARGS=20260101-120000"

list:
	@./debloat/debloat.sh list

check:
	@./debloat/debloat.sh check $(ARGS)

apply:
	@./debloat/debloat.sh apply $(ARGS)

restore:
	@./debloat/debloat.sh restore $(ARGS)

fetch-apks:
	@./tools/fetch-apks.sh
