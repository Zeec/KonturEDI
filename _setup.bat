rem EDIKontur

set server_name=nb-spb-tpad03
set database_name=DBZee_9_5_0
set user_name=sa
set user_password=sasa

for %%f in (*.sql) do sqlcmd -S %server_name% -d %database_name% -U %user_name% -P %user_password% -i %%f

