# Configuration variables for scripts

dialect = "mssql+pyodbc"                    # For SQL Query
sqluser = "tav"                             # SQL User
sqlpassword = "tav"                         # SQL user's password (plain)
sqlhost = "RUSHVTRCSQLP22"                  # SQL database host
sqldatabase = "AntaresTracking_PROD"        # SQL database name
sqldriver = "/opt/microsoft/msodbcsql17/lib64/libmsodbcsql-17.10.so.4.1"

work_dir = '\\\\shuvoe.rg-rus.ru\\Root_DFS\\Общие документы завода\\Производственная дирекция\\Фармацевтический склад\\Comparer'
source_dir = "{}\\input".format(work_dir)
target_dir = "{}\\complete".format(work_dir)
log_dir = "{}\\log".format(work_dir)

user_cert_thumbprint = '559F01F3A05A8505B4C18968E4570FC51A3FC196'
subject_id = "00000000223912"
#subject_id = "00000000114590"
nsmap1 = {'xsi': 'http://www.w3.org/2001/XMLSchema-instance'}
nsmap = nsmap1

email_from = 'checker@shv-vapp05.ru'
# email_to = the list of all recipients' email addresses
email_to = ['goncharenkoai@rg-rus.ru',
            'GordienkoKA@rg-rus.ru',
            'BelashovaNV@rg-rus.ru',
            'MoskovkinaEV@rg-rus.ru',
            'NazarovaAV@rg-rus.ru',
            'ChurilovaTG@rg-rus.ru',
            'Dronova@rg-rus.ru']

queue_parallel = True
retry_enabled = True

