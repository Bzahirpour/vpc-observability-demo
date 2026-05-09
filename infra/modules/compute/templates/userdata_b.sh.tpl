#!/bin/bash
# Instance B: isolated demo target.
# Amazon Linux 2023 ships with the SSM agent pre-installed, so no setup needed.
#
# This instance has NO inbound security group rules. Every connection attempt
# from Instance A is blocked at the SG, generating action=REJECT entries in
# the VPC Flow Log — that is the point of this instance's existence.
