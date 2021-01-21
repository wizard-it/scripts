import os
import re
import csv
import time
import ldap3
import logging
from hashlib import md5
from ast import literal_eval
from argparse import ArgumentParser
from configparser import RawConfigParser
from logging.handlers import RotatingFileHandler
from ldap3.core.exceptions import LDAPSocketOpenError


def read_config(path):
    """
    The function reads csv2ldap.conf config file and returns RawConfigParser object.

    :param path:
    Path to config file
    :return:
    configparser.RawConfigParser object.
    """

    cfg = RawConfigParser()
    if os.path.exists(path):
        cfg.read(path)
        return cfg
    else:
        # Creating 'startup_error.log' if config file cannot be open
        with open('startup_error.log', 'w') as err_file:
            err_file.write('ERROR: Cannot find "csv2ldap.conf" fine in current directory.')
            raise SystemExit('Missing config file (csv2ldap.conf) in current directory')


def write_log(logger, err_level, message):
    """
    Writes string to log using logging module.

    :param logger:
    Logger object to use.
    :param err_level:
    Logging level - INFO, WARNING etc (also can be int - 20 for INFO, 30 for WARNING etc).
    :param message:
    String to write.
    :return:
    None
    """

    codes_to_int = {'DEBUG': 10, 'INFO': 20, 'WARNING': 30, 'ERROR': 40, 'CRITICAL': 50}
    if message is not None:
        logger.log(codes_to_int[err_level], message)
    else:
        logger.log(20, 'Logger has just got "None" for write to log. Going ahead.')


def get_logger():
    """
    Getting logger object.

    :return:
    Logger object
    """

    # Parse log size
    units = {'B': 1, 'KB': 10**3, 'MB': 10**6}
    if len(LOG_SIZE.split()) == 2:
        number, unit = LOG_SIZE.split()
        log_bytes = int(float(number) * units[unit.upper()])
    else:
        log_bytes = float(LOG_SIZE)

    # Define logger parameter
    logging.basicConfig(level=LOG_LEVEL)
    log_formatter = logging.Formatter(fmt="%(levelname)s;%(asctime)s;%(message)s", datefmt=DATE_FMT)
    log_handler = RotatingFileHandler(filename=LOG_PATH, maxBytes=log_bytes, backupCount=LOG_COUNT, encoding='utf-8')

    log_handler.setFormatter(log_formatter)
    logger = logging.getLogger()
    logger.addHandler(log_handler)
    return logger


def ldap_connect(ldap_server, ldap_user, ldap_password):
    """
    Establishing connection with LDAP server.

    :param ldap_server:
    str() LDAP server name or IP address.
    :param ldap_user:
    str() Username (sAMAccountName) using to connect with NTLM.
    :param ldap_password:
    str() User password.
    :return:
    ldap3.Connection object.
    """

    srv = ldap3.Server(ldap_server, get_info='ALL', mode='IP_V4_PREFERRED', use_ssl=LDAP_SSL)
    try:
        conn = ldap3.Connection(srv, auto_bind=True, authentication='NTLM', user=ldap_user, password=ldap_password)
    except LDAPSocketOpenError as e:
        write_log(LOGGER, 'CRITICAL', "Cannot connect to LDAP server: {}".format(ldap_server))
        raise SystemExit('ERROR: {}'.format(e.__str__()))
    return conn


def update_user(conn, user_dn, updates):
    """
    Updates LDAP user's object by it's DistinguishedName. Also takes dict, what has info how to update values.
    Dict format describe in ldap3 project documentation and represents similar structure:
    {'attribute_name': [('MODIFY_REPLACE', [new_val.encode()])]}

    :param conn:
    ldap3.Connection object.
    :param user_dn:
    DistinguishedName of modified object.
    :param updates:
    Dict with attributes to update.
    :return:
    Two element tuple - (True/False, Description).
    """

    return conn.modify(user_dn, updates), conn.result['description']


def get_users(conn, searchfilter, attrs):
    """
    Function search users in LDAP catalog using search filter in config file.

    :param conn:
    ldap3.Connection object.
    :param searchfilter:
    LDAP search filter from config file.
    :param attrs:
    List of attributes to get from catalog.
    :return:
    dict with all found objects.
    """

    base_dn = conn.server.info.other['rootDomainNamingContext'][0]
    conn.search(search_base=base_dn, search_filter=searchfilter, attributes=attrs)
    ldap_users = conn.entries
    return ldap_users


def get_dn(conn, employeeid):
    """
    Function gets user DistinguishedName from LDAP catalog by attribute.

    :param conn:
    ldap3.Connection object.
    :param employeeid:
    LDAP attribute data.
    :return:
    List with LDAP user DN's.
    """

    filter_str = '(&(objectClass=user)(EmployeeID={}))'.format(employeeid)

    # Search in LDAP with our filter
    conn.search(conn.server.info.other['rootDomainNamingContext'], filter_str)
    dn_list = [entry.entry_dn for entry in conn.entries]
    return dn_list


def preprocessing(attr_value, method):
    """
    The function realize some preprocessing functionality for attributes.

    :param attr_value:
    <str>
    LDAP attribute to modify
    :param method:
    <str>
    What we want to do with attr. Can be 'capitalize', 'title', 'lower' and 'upper' for strings.
    :return:
    <str>
    Corrected attribute.
    """

    if method.startswith('replace'):
        # Making tuple with replacement data without the first 'replace' word.
        try:
            replace_expr = literal_eval(method[7:])
        except SyntaxError:
            raise SystemExit('ERROR: Cannot parse replacement expression {}. Check it.'.format(method[7:]))
        # If the first element of replace_tuple is <tuple>, so we have nested tuple. Walking through them.
        if type(replace_expr[0]) is tuple:
            for nested_tuple in replace_expr:
                regexp, repl_str = nested_tuple
                attr_value = re.sub(regexp, nested_tuple[1], attr_value)
            # When nested tuples is ended, write 'new_attr' value
            else:
                new_attr = attr_value
        else:
            regexp, repl_str = replace_expr
            new_attr = re.sub(regexp, repl_str, attr_value)
    elif method == 'capitalize':
        new_attr = attr_value.capitalize()
    elif method == 'title':
        new_attr = attr_value.title()
    elif method == 'lower':
        new_attr = attr_value.lower()
    elif method == 'upper':
        new_attr = attr_value.upper()
    else:
        new_attr = None
    return new_attr


def normalize_mobile(phone_number):
    """
    The function transform phone number to one format.
    :param phone_number:
    str() String with phone number.
    :return:
    str() New phone number.
    """

    if re.match(r'^\d[-\s]?(\d{3}-){2}(\d{2}-?){2}', phone_number):
        old = phone_number.replace('-', '').replace(' ', '')
        new = "+7 ({0}) {1}-{2}-{3}".format(old[1:4], old[4:7], old[7:9], old[9:11])
    else:
        # Default - set value as is
        new = phone_number
    return new


def check_csv(data_file):
    """
    The function validate CSV file structure.

    :param data_file:
    str() Path to CSV file with data.
    :return:
    True if all fields are unique and tuple (False, list()) if not.
    """

    empl_ids = []
    not_unique = set()

    # Check csv header and fill employeeIDs list
    with open(data_file, 'r', encoding=CSV_ENCODING) as file:
        rows = csv.reader(file, delimiter=CSV_DELIM)
        header = [item.lower() for item in next(rows)]
        header_length = len(header)
        for row in rows:
            row_len = len(row)
            if row_len > 0:
                empl_ids.append(row[0])
            if row_len != header_length and row_len != 0:
                return False, "CSV File content error. Check line {}.".format(rows.line_num)

    # Check employeeID unique
    for empl_id in empl_ids[1:]:
        if empl_ids.count(empl_id) > 1:
            not_unique.add(empl_id)
    if len(not_unique) > 0:
        return False, "Duplicated employee ID's in CSV file: {}".format(', '.join(not_unique))
    else:
        return True, header


def load_csv(conn, data_file, data_file_header):
    """
    The function prepares CSV data to synchronize with LDAP. It's read the file, process it and return dict with
    data for update.

    :param conn:
    ldap3.Connection object.
    :param data_file:
    str() Path to CSV datafile.
    :param data_file_header:
    Header of data_file.
    :return:
    Tuple with csv header and dict() like this:
    {'0000001029': {'sn': 'Ivanov', 'givenName': 'Ivan'}}
    """

    all_employees = {}

    # Opening CSV file and read it as dict
    with open(data_file, 'r', encoding=CSV_ENCODING) as users_csv:
        csv_data = csv.reader(users_csv, delimiter=CSV_DELIM)
        next(csv_data)
        for row in csv_data:
            if len(row) != 0:
                user = dict(zip(data_file_header, row))
                empl_id = user['employeeid']
                update_attrs = set(data_file_header) - set(LDAP_CALC_ATTRS)

                # If user in exception list, subtract it's attrs from all update attributes in config file
                if empl_id in EXCEPTION_DICT:
                    if EXCEPTION_DICT[empl_id][0] == '*':
                        continue
                    update_attrs = update_attrs - set(EXCEPTION_DICT[empl_id])
                update_dict = {}

                # Do preprocessing if needed
                for attr in update_attrs:
                    if attr in PREP_DICT:
                        prep_rule = PREP_DICT[attr]
                        corrected_attr = preprocessing(user[attr], prep_rule)
                        update_dict[attr] = corrected_attr.strip()
                    else:
                        update_dict[attr] = user[attr].strip()

                # Calculate rest attributes
                # Initials and Description
                sn = update_dict['sn']
                given_name = update_dict['givenname']
                middle_name = update_dict['middlename']

                if middle_name != '':
                    update_dict['initials'] = "{}. {}.".format(given_name[0], middle_name[0])
                    update_dict['description'] = '{} {} {}'.format(sn, given_name, middle_name)
                else:
                    update_dict['initials'] = "{}.".format(given_name[0])
                    update_dict['description'] = '{} {}'.format(sn, given_name)

                # DisplayName
                update_dict['displayname'] = '{} {}'.format(sn, update_dict['initials'])

                # mobile
                update_dict['mobile'] = normalize_mobile(user['mobile'])

                # manager
                manager_dn = get_dn(conn, user['manager'])
                if len(manager_dn) == 1:
                    manager_dn = manager_dn[0]
                elif len(manager_dn) > 0:
                    manager_dn = ""
                    write_log(LOGGER, 'WARNING', "Found '{}' users for '{}' employeeid".format(
                        len(manager_dn), user['manager']))
                update_dict['manager'] = manager_dn

                # Fill extensionAttribute1, extensionAttribute2
                update_dict['extensionAttribute1'] = user['department'].strip()
                update_dict['extensionAttribute2'] = user['title'].strip()

                # Put update_dict to the global dict
                all_employees[empl_id] = update_dict
    return all_employees


def run_update(conn, data_file, data_header):
    """
    The function runs update process.

    :param conn:
    Result of ldap_connect() function.
    :param data_file:
    Path to CSV file.
    :param data_header:
    Header of csv data file.
    :return:
    None
    """

    # Loading CSV file
    csv_data = load_csv(conn, data_file, data_header)
    attrs_to_update = data_header + LDAP_CALC_ATTRS
    # Getting all need users from LDAP
    if DEBUG:
        write_log(LOGGER, 'DEBUG', 'Loading data from LDAP')
    ad_users = get_users(conn, LDAP_SEARCHFILTER, attrs_to_update + ['samaccountname'])
    if DEBUG:
        write_log(LOGGER, 'DEBUG', 'Retrieve {} records'.format(len(ad_users)))

    for user in ad_users:
        samname = user.sAMAccountName.value
        eid = user.employeeID.value
        user_dn = user.entry_dn
        if DEBUG:
            write_log(LOGGER, 'DEBUG', "Checking user '{}' with id '{}'".format(samname, eid))

        if eid in csv_data:
            if DEBUG:
                write_log(LOGGER, 'DEBUG', "Employeeid '{}' found in CSV".format(eid))
                write_log(LOGGER, 'DEBUG', "Attributes to update: '{}'".format(list(csv_data[eid].keys())))
            # Forming update dict for one-time update of many attributes
            update_dict = {}

            for attr in csv_data[eid].keys():
                if DEBUG:
                    write_log(LOGGER, 'DEBUG', "Checking '{}'".format(attr))
                curr_val = user[attr].value
                new_val = csv_data[eid][attr]
                if DEBUG:
                    write_log(LOGGER, 'DEBUG', "LDAP: '{}', CSV: '{}'".format(curr_val, new_val))
                if curr_val is None:
                    curr_val = ""
                if curr_val != new_val:
                    if DEBUG:
                        write_log(LOGGER, 'DEBUG', "'{}' needs update".format(attr, curr_val, new_val))
                    if new_val:
                        update_dict[attr] = [('MODIFY_REPLACE', [new_val.encode()])]
                    else:
                        update_dict[attr] = [('MODIFY_DELETE', [curr_val])]
                else:  # DEBUG
                    write_log(LOGGER, 'DEBUG', "'{}' LDAP equal CSV. Skipping".format(attr))

            # Running update
            if update_dict:
                upd_res, upd_msg = update_user(conn, user_dn, update_dict)
                if upd_res:
                    write_log(LOGGER, 'INFO', '{} : {} : {}'.format(samname, ', '.join(update_dict.keys()), upd_msg))
                else:
                    write_log(LOGGER, 'ERROR', '{} : {} : {}'.format(samname, ', '.join(update_dict.keys()), upd_msg))
        # Write to log, if user not found in CSV
        else:
            write_log(LOGGER, 'INFO', "User '{}' with ID '{}' not found in CSV. Skipping".format(samname, eid))
    if not ONE_TIME:
        print('{}: Task has been completed, waiting {} seconds'.format(time.strftime('%d.%m.%Y %X'), WAIT_SEC))
    else:
        print('{}: Task has been completed'.format(time.strftime('%d.%m.%Y %X')))


if __name__ == '__main__':
    # Current program version
    VERSION = '0.1'

    # Parse all given arguments
    parser = ArgumentParser(description='Script for load data from CSV to LDAP catalog.', add_help=True)
    parser.add_argument('-c', '--config', type=str, default='csv2ldap.conf', help='Path to config file')
    parser.add_argument('-w', '--wait', type=int, help='Timeout in seconds before next circle')
    parser.add_argument('-v', '--version', action='version', version=VERSION, help='Print script version and exit')
    parser.add_argument('-o', '--onetime', action='store_true', help='Start once and exit')
    parser.add_argument('--debug', action='store_true', help='Enables debug mode')
    parser.add_argument('--showcfg', action='store_true', help='Show loaded config and exit')
    args = parser.parse_args()

    # Lading config from file
    config = read_config(args.config)

    for section in ['MAIN', 'CSV', 'LDAP']:
        if not config.has_section(section):
            raise SystemExit('CRITICAL: Config file missing "{}" section'.format(section))

    # MAIN section
    WAIT_SEC = config.getint('MAIN', 'wait', fallback=30)
    DATE_FMT = config.get('MAIN', 'DateFormat', fallback='%d.%m.%Y %X')

    # LOGGING section
    LOG_LEVEL = config.get('LOGGING', 'level', fallback='INFO')
    LOG_PATH = config.get('LOGGING', 'LogPath', fallback='')
    LOG_SIZE = config.get('LOGGING', 'MaxFileSize', fallback=1048576)
    LOG_COUNT = config.getint('LOGGING', 'rotation', fallback=2)

    # Creating logger
    LOGGER = get_logger()

    # Is debug enabled
    if args.debug or LOG_LEVEL == 'DEBUG':
        DEBUG = True
        print('DEBUG mode: ON')
    else:
        print('DEBUG mode: OFF')
        DEBUG = False

    # LDAP section
    LDAP_SERVER = config.get('LDAP', 'server')
    LDAP_USER = config.get('LDAP', 'username')
    LDAP_PASSWORD = config.get('LDAP', 'password')
    LDAP_SSL = config.getboolean('LDAP', 'use_ssl', fallback=False)
    LDAP_SEARCHFILTER = config.get('LDAP', 'searchfilter', fallback='(&(objectCategory=person)(objectclass=user)')
    LDAP_CALC_ATTRS = [attr.lower() for attr in config.get('LDAP', 'calculated_attrs').split(',')]

    # CSV section
    CSV_FILE = config.get('CSV', 'CsvPath')
    CSV_DELIM = config.get('CSV', 'Delimiter', fallback=';')
    CSV_ENCODING = config.get('CSV', 'Encoding', fallback='utf-8')

    # EXCEPTION section
    if config.has_section('EXCEPTIONS') and config.items('EXCEPTIONS'):
        EXCEPTION_DICT = dict((eid, attrs.split(',')) for eid, attrs in config.items('EXCEPTIONS'))
    else:
        EXCEPTION_DICT = {}

    # PREPROCESSING section
    if config.has_section('PREPROCESSING') and config.items('PREPROCESSING'):
        PREP_DICT = dict((attr.lower(), value) for attr, value in config.items('PREPROCESSING'))

    if args.showcfg:
        for section in config.sections():
            print("\n[{}]".format(section))
            for option in config.options(section):
                print("{0:25} = {1:}".format(option, config.get(section, option)))
        exit(0)

    # Computerame
    COMPUTERNAME = os.environ['COMPUTERNAME'] if os.name == 'nt' else os.environ['HOSTNAME']

    # Is running for one time
    ONE_TIME = args.onetime

    if args.wait:
        WAIT_SEC = args.wait

    if not args.onetime:
        init_md5 = ''
        write_log(LOGGER, 'INFO', 'Starting csv2ldap on {}'.format(COMPUTERNAME))
        print('\n{}: csv2ldap started.\nPress CTRL-C to stop it...'.format(time.strftime(DATE_FMT)))
        while True:
            try:
                try:
                    with open(CSV_FILE, 'rb') as csv_file:
                        current_md5 = md5(csv_file.read()).hexdigest()
                except (IOError, FileNotFoundError):
                    write_log(LOGGER, 'CRITICAL', 'Cannot read CSV file: {}'.format(CSV_FILE))
                    raise SystemExit('Cannot read CSV file: {}'.format(CSV_FILE))

                if init_md5 != current_md5:
                    print('{}: Update task started'.format(time.strftime(DATE_FMT)))
                    csv_stat, csv_header = check_csv(CSV_FILE)
                    if csv_stat is True:
                        with ldap_connect(LDAP_SERVER, LDAP_USER, LDAP_PASSWORD) as ldap_conn:
                            run_update(ldap_conn, CSV_FILE, csv_header)
                    else:
                        write_log(LOGGER, 'ERROR', "{}".format(csv_header))
                    time.sleep(WAIT_SEC)
                else:
                    time.sleep(WAIT_SEC)
                init_md5 = current_md5
            except KeyboardInterrupt:
                raise SystemExit('{}: csv2ldap stopped by the user'.format(time.strftime(DATE_FMT)))
    else:
        write_log(LOGGER, 'INFO', 'Starting csv2ldap at {} on {}'.format(time.strftime(DATE_FMT), COMPUTERNAME))
        print('{}: One time update task started'.format(time.strftime(DATE_FMT)))
        csv_stat, csv_header = check_csv(CSV_FILE)
        if csv_stat is True:
            with ldap_connect(LDAP_SERVER, LDAP_USER, LDAP_PASSWORD) as ldap_conn:
                run_update(ldap_conn, CSV_FILE, csv_header)
                exit(0)
        else:
            write_log(LOGGER, 'ERROR', "{}".format(csv_header))
