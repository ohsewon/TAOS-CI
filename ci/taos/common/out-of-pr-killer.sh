#!/usr/bin/env bash

##
# Copyright (c) 2018 Samsung Electronics Co., Ltd. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

##
# @file   out-of-pr-killer.sh
# @brief  Out-of-PR((OOP) Killer
#
# This facility is to stop compulsorily the previous same PRs invoked by
# checker-pr-gateway.sh when the developers try to send a lot of same PRs
# repeatedly.
# 


# --------------------------- Out-of-PR (OOP) killer: kill previous same PRs  ----------------------------------

##
# @brief Run out-of-pr(OOP) killer
function run_oop_killer(){
    # Specify dependent commands for this function.
    check_dependency ps
    check_dependency awk
    check_dependency grep
    check_dependency bc
    check_dependency kill
    check_dependency sleep
    check_dependency rm

    # Run the OOP killer
    # Kill PRs that were previously invoked by checker-pr-gateway.sh with the same PR number.
    echo "[DEBUG] OOP Killer: Kill the existing same PRs that is previously invoked by checker-pr-gateway.sh.\n"
    ps aux | grep "^www-data.*bash \./checker-pr-gateway.sh" | while read line
    do
        victim_pr=`echo $line  | awk '{print $17}'`
        victim_date=`echo $line  | awk '{print $13}'`
        # Step 1: The victim pid1 is checker-pr-gateway.sh (It is a task distributor.)
        # Step 2: The victim pid2 is checker-pr-audit-async.sh (It is a audit group.)
        # Step 3:
        # a. The victim pid3_tizen:  "gbs build" command for a tizen build
        # b. The victim pid3_ubuntu: "pdebuild" command for a ubuntu build 
        victim_pid1=`ps -ef | grep bash | grep checker-pr-gateway.sh       | grep $input_pr | grep $victim_date | awk '{print $2}'`
        victim_pid2=`ps -ef | grep bash | grep checker-pr-audit-async.sh | grep $input_pr | grep $victim_date | awk '{print $2}'`
        victim_pid3_tizen=`ps -ef | grep python | grep gbs | grep "_pr_number $input_pr" | grep $victim_date | awk '{print $2}'`
        victim_pid3_ubuntu=`ps -ef | grep bash | grep pdebuild | grep "_pr_number $input_pr" | grep $victim_date | awk '{print $2}'`
        # Todo: NYI, Implement the OOP killer for Yocto  build (devtool)
        victim_pid3_yocto=""
    
        # The process killer allows to kill only task(s) in case that there are running lots of tasks with same PR number.
        if [[ ("$victim_pr" -eq "$input_pr") && (1 -eq "$(echo "$victim_date < $input_date" | bc)") ]]; then
            echo "[DEBUG] OOP Killer: Killing 'checker-pr-gateway.sh' process..."
            kill $victim_pid1

            echo "[DEBUG] OOP Killer: Killing 'checker-pr-audit-async.sh' process..."
            kill $victim_pid2

            echo "[DEBUG] OOP Killer/Tizen: victim_pr=$victim_pr, input_pr=$input_pr, victim_date=$victim_date, input_date=$input_date "
            echo "[DEBUG] OOP Killer/Tizen: killing PR $victim_pr (pid <$victim_pid1> <$victim_pid2> <$victim_pid3_tizen>)."
            kill $victim_pid3_tizen

            echo "[DEBUG] OOP Killer/Ubuntu: victim_pr=$victim_pr, input_pr=$input_pr, victim_date=$victim_date, input_date=$input_date "
            echo "[DEBUG] OOP Killer/Ubuntu: killing PR $victim_pr (pid <$victim_pid1> <$victim_pid2> <$victim_pid3_ubuntu>)."
            kill $victim_pid3_ubuntu

            # Handle a possibility that someone updates a single PR multiple times within 1 second.
            sleep 1
            echo "[DEBUG] OOP Killer: removing the out-of-date ./${dir_worker}/${victim_pr}-${victim_date}-* folder"
            rm -rf ./${dir_worker}/${victim_pr}-${victim_date}-*
        fi
    done
}

