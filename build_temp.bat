@echo off
set "DEVECO_SDK_HOME=C:\devlop\devecostudio\DevEco Studio\sdk"
set "HARMONYOS_SDK_HOME=C:\devlop\devecostudio\DevEco Studio\sdk"
set "NODE_HOME=C:\devlop\devecostudio\DevEco Studio\tools\node"
set "PATH=C:\devlop\devecostudio\DevEco Studio\tools\node;C:\devlop\devecostudio\DevEco Studio\tools\ohpm\bin;%PATH%"
cd /d "C:\devlop\devecostudio\workspace\zhizon"
"C:\devlop\devecostudio\DevEco Studio\tools\node\node.exe" "C:\devlop\devecostudio\DevEco Studio\tools\hvigor\bin\hvigorw.js" assembleHap --mode module -p module=entry --no-daemon
