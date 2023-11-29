import os
import pyodbc
import psycopg2

from dotenv import load_dotenv

load_dotenv()

# Класс обработки обмена данных из баз
class SqlExchange:

    # Инициализация класса
    def __init__(self):
        self.source = os.getenv('CONNECTION_SOURCE')
        self.target = os.getenv('CONNECTION_TARGET')

    # Метод экспорта данных
    def exportData(self):
        # print(f'Подключение к целевой таблице')
        conn = self.getConnect(self.target);
        cursor = conn.cursor()

        # print(f'Получение данных из источника')
        records = self.getSourceData()

        # print(f'Количество записей для добавления: {len(records)}')
        for r in records:
            self.insertRecordToTarget(cursor, r)

        cursor.close()
        conn.close()

    # Получение данных из Source
    def getSourceData(self):
        global query;

        lastIndex = self.getLastIDTarget()
        conn = self.getConnect(self.source);
        cursor = conn.cursor()

        # print(f'Последний индекс: {lastIndex}')

        # Проверка на обновление данных, 
        # если последний индекс отсутствует (нет данных), то возвращаем пустой массив для обновления, 
        # если индекс -1 (создана новая целевая таблица), то импортируем данные за вчера и сегодня, 
        # иначе получаем данные, созданные после предыдущей записи
        match lastIndex:
            case -1:
                # print(f'Получаем за предыдущий день')
                query = os.getenv('MSSQL_QUERY_GET_PREV_DAY')
            case None:
                # print(f'Нет данных для обновления')
                cursor.close() 
                conn.close() 
                return []
            case _:
                # print(f'Получаем новые обновленные элементы')
                query = os.getenv('MSSQL_QUERY_GET_NEW').format(lastIndex)
         # Выплняем запрос на получение записей
        cursor.execute(query)
        # Передаем в переменную полученый массив с данными
        records = cursor.fetchall()
        # Закрываем подключения
        cursor.close() 
        conn.close() 

        return records

    # Запись события в целевую таблицу
    def insertRecordToTarget(self, cursor, record):
        query = os.getenv('POSTGRESQL_QUERY_INSERT').format(
            record.id, 
            record.fInitObjName, 
            record.fRealTime, 
            record.fID1, 
            record.fHolderName
        )
        cursor.execute(query)
        
    # Получение последнего значения ID из родителя
    def getLastIDTarget(self): 
        global query
        
        conn = self.getConnect(self.target);
        cursor = conn.cursor()
        # Пробуем получить данные, если запрос не выполнен - 
        # отсутствует или не найдена нужная таблица, то создаем ее
        try:
            query = os.getenv('POSTGRESQL_QUERY_GET_LAST')
            cursor.execute(query)
            return cursor.fetchone()[0]
        except:
            query = os.getenv('POSTGRESQL_QUERY_CREATE_TABLE')
            cursor.execute(query)
            return -1

    # Подключение к БД в зависимости от типа подключения
    def getConnect(self, connType):
        match connType:
            case 'MSSQL':
                return self.connectToMSSQL()
            case 'PostgreSQL':
                conn = self.connectToPostgreSQL()
                conn.autocommit = True
                return conn

    # Подключение к MSSQL
    def connectToMSSQL(self):
        try:
            return pyodbc.connect(f'''
                DRIVER={os.getenv('MSSQL_CONNECTION_DRIVER')};
                SERVER={os.getenv('MSSQL_CONNECTION_SERVER')};
                DATABASE={os.getenv('MSSQL_CONNECTION_DATABASE')};
                UID={os.getenv('MSSQL_CONNECTION_UID')};
                PWD={os.getenv('MSSQL_CONNECTION_PASS')};
                TrustServerCertificate={os.getenv('MSSQL_CONNECTION_TSR')}''')
        except:
            print('Error. Не получилось подключиться к БД\n')

    # Подключение к PostgreSQL
    def connectToPostgreSQL(self):
        try:
            return psycopg2.connect(
                database=os.getenv('POSTGRESQL_CONNECTION_DATABASE'),
                host=os.getenv('POSTGRESQL_CONNECTION_HOST'),
                user=os.getenv('POSTGRESQL_CONNECTION_USERNAME'),
                password=os.getenv('POSTGRESQL_CONNECTION_PASS'),
                port=os.getenv('POSTGRESQL_CONNECTION_PORT'))
        except:
            print('Error. Не получилось подключиться к БД\n')