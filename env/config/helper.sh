#!/bin/bash
sed -i "s/\"TargetValue\": [^,]*/\"TargetValue\": $ASG_TARGET/" "./config.json"