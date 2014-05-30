

#

help:
	@echo "      You can do :"
	@echo "make test"

.PHONY: test test_paypal_build_reply

test: test_paypal_build_reply

test_init: test_paypal_build_reply_init

test_paypal_build_reply_init:
	./paypal_build_reply /g/var/paypal_build_reply/msg-5088-3.txt /g/var/paypal_build_reply/_1395313727_30838_paypal_com_  > /g/var/paypal_build_reply/t01_paypal_build_reply_support_ref.out
	./paypal_build_reply /g/var/paypal_build_reply/msg-4425-3.txt /g/var/paypal_build_reply/_1396257031_22182_paypal_com_ > /g/var/paypal_build_reply/t01_paypal_build_reply_software_ref.out
	./paypal_build_reply --debug /g/var/paypal_build_reply/msg-5088-3.txt /g/var/paypal_build_reply/_1395313727_30838_paypal_com_  > /g/var/paypal_build_reply/t01_paypal_build_reply_support_debug_ref.out
	./paypal_build_reply --debug /g/var/paypal_build_reply/msg-4425-3.txt /g/var/paypal_build_reply/_1396257031_22182_paypal_com_ > /g/var/paypal_build_reply/t01_paypal_build_reply_software_debug_ref.out


test_paypal_build_reply:
	./paypal_build_reply /g/var/paypal_build_reply/msg-5088-3.txt /g/var/paypal_build_reply/_1395313727_30838_paypal_com_  > /g/var/paypal_build_reply/t01_paypal_build_reply_support_new.out
	diff /g/var/paypal_build_reply/t01_paypal_build_reply_support_ref.out /g/var/paypal_build_reply/t01_paypal_build_reply_support_new.out 
	./paypal_build_reply /g/var/paypal_build_reply/msg-4425-3.txt /g/var/paypal_build_reply/_1396257031_22182_paypal_com_ > /g/var/paypal_build_reply/t01_paypal_build_reply_software_new.out
	diff /g/var/paypal_build_reply/t01_paypal_build_reply_software_ref.out /g/var/paypal_build_reply/t01_paypal_build_reply_software_new.out
	./paypal_build_reply --debug /g/var/paypal_build_reply/msg-5088-3.txt /g/var/paypal_build_reply/_1395313727_30838_paypal_com_  > /g/var/paypal_build_reply/t01_paypal_build_reply_support_debug_new.out
	diff /g/var/paypal_build_reply/t01_paypal_build_reply_support_debug_ref.out /g/var/paypal_build_reply/t01_paypal_build_reply_support_debug_new.out 
	./paypal_build_reply --debug /g/var/paypal_build_reply/msg-4425-3.txt /g/var/paypal_build_reply/_1396257031_22182_paypal_com_ > /g/var/paypal_build_reply/t01_paypal_build_reply_software_debug_new.out
	diff /g/var/paypal_build_reply/t01_paypal_build_reply_software_debug_ref.out /g/var/paypal_build_reply/t01_paypal_build_reply_software_debug_new.out

