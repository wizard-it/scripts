# from lxml import etree
from datetime import datetime, timedelta
import time
import logging
import logging.handlers as handlers
from logging import Formatter
# import random
# import shutil
from os import listdir, path

# import os

# source_dir = '.\\input'
# target_dir = '.\\complete'
# v11 - Parallel documents processing disabling
# v12 - Retry implementation
# v13 - Auto parallel switcher

rgr_path = '\\\\shuvoe.rg-rus.ru\\Root_DFS\\Общие документы завода\\Производственная дирекция\\Фармацевтический склад\\Comparer'

source_dir = f'{rgr_path}\\input'
target_dir = f'{rgr_path}\\complete'
log_dir = f'{rgr_path}\\log'
thumbprint = '559F01F3A05A8505B4C18968E4570FC51A3FC196'

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
logHandler = handlers.RotatingFileHandler(f'{log_dir}\\app.log', maxBytes=50 ** 6, backupCount=5)
logHandler.setFormatter(Formatter(fmt='[%(asctime)s: %(levelname)s] %(message)s'))
logHandler.setLevel(logging.DEBUG)
logger.addHandler(logHandler)
logger.debug(f"{'#' * 20} Job started {'#' * 20}")

logger.debug(f'Thumbprint is: {thumbprint}')

email_from = 'checker@shv-vapp05.ru'
email_to = ['goncharenkoai@rg-rus.ru',
            'GordienkoKA@rg-rus.ru',
            'BelashovaNV@rg-rus.ru',
            'MoskovkinaEV@rg-rus.ru',
            'NazarovaAV@rg-rus.ru',
            'ChurilovaTG@rg-rus.ru',
            'Dronova@rg-rus.ru']  # email_to = the list of all recipients' email addresses

queue_parallel = True  # True
retry_enabled = True

file_names = listdir(source_dir)
if file_names:
    # we do not need in that modules if nothing to do:
    print('Start modules import...')
    from filelock import FileLock
    from shutil import move
    from upload_xml_to_MDLP import upload_xml_to_mdlp
    from check_accepted_mdlp import get_document_status_mdlp
    from email_notification_to_group import send_email_rg_rus
    from sgtins_by_list_mdlp import sgtins_by_list_request, response_parser_sgtins, response_parser_sscc_check
    from get_sscc_exists_MDLP import get_sscc_exists_mdlp_request
    from get_metadata_for_342_doc import get_metadata_for_342_doc, get_metadata_for_313_doc
    from get_sscc_exists_MDLP import get_sscc_exists_mdlp
    from operation_queue import operation_queue_generator, same_docs
    import re
    from get_sscc_hierarchy_antares import get_sscc_hier_ant, check_sscc_homogeneous_antares
    from get_sscc_hierarchy_MDLP import get_mdlp_sscc_full_hier
    import json
    import pandas as pd
    from math import ceil

    print('Modules imported...')
    full_hierarchy_last_run = datetime.now() - timedelta(days=1)
    print(f"{'#' * 50}")
    print(f"{'#' * 8}  Parse file and Get hierarchy:   {'#' * 8}")
    print(f"{'#' * 50}")
    logger.debug(f"{'#' * 5}  Parse file and Get hierarchy:")

sscc_all = []
for file_name in file_names:
    email_subject = 'Hierarchy checker for Antares'
    email_body = []
    input_path = path.join(source_dir, file_name)
    lock = FileLock(input_path, force=False)
    with lock:
        print(f'Processing file_name: {input_path}')
        logger.debug(f'Processing file_name: {input_path}')
        email_body.append(f'Processing file_name: {file_name}')
        # Parse input file
        column_names = ['col_a', 'col_b', 'col_c', 'col_d']
        df = pd.read_csv(input_path, delimiter='\t', dtype=object, header=None, names=column_names)

        # select unique SSCC
        package_template = '(?:01(\\d{14})|10([a-zA-Z0-9]{1,20})(\\x1d)?|17(\\d{6})|21([a-zA-Z0-9]{1,20})(\\x1d)?)'
        sscc_template = '^00(\\d{18})$'

        for index, row in df.iterrows():
            for column_name in column_names:
                if not pd.isna(row[column_name]) and re.search(sscc_template, row[column_name]) \
                        and row[column_name] not in sscc_all:
                    sscc_all.append(row[column_name])

        print(f'sscc_all: {sscc_all}')
        logger.debug(f'sscc_all: {sscc_all}')
        email_body.append(f'Parsed SSCCs to check: {sscc_all}')

        # Check every serial on Antares side to check if it is Case or Pallet, Cases will be processed first. Output is DataFrame with aggregation information:
        case_hier_dict_ant = {}
        pallet_hier_dict_ant = {}
        for sscc in sscc_all:
            sscc_to_add = sscc[2:]
            df_sscc = get_sscc_hier_ant(sscc)
            if not df_sscc.empty:
                if df_sscc['child_level_1_CodingRule'][0] == 'GS1_SGTIN_RU':
                    sgtins = df_sscc['child_level_1_Serial'].tolist()
                    antares_parent = df_sscc['up'][0]
                    case_hier_dict_ant[sscc_to_add] = {'parent': antares_parent, 'sgtin': sgtins}
                elif df_sscc['child_level_1_CodingRule'][0] == 'GS1_SSCC':
                    cases = df_sscc['child_level_1_Serial'].unique().tolist()
                    pallet_hier_dict_ant[sscc_to_add] = {'cases': cases}
            else:
                print(f'SSCC is empty: {sscc}')
                logger.debug(f'SSCC is empty: {sscc}')
                email_body.append(f'SSCC is empty: {sscc}')
        print('cases_dict_antares: ', case_hier_dict_ant)
        logger.debug(f'cases_dict_antares: {case_hier_dict_ant}')


        # this function will parse response and returns dictionary with MDLP side hierarchy
        def mdlp_response_parse_childs(response_f):
            mdlp_parse_result_f = {}
            # global mdlp_parse_result
            if response_f:
                mdlp_result = json.loads(response_f)
                k = len(mdlp_result)
                i = 0
                while i < k:
                    # print(i)
                    mdlp_parent = mdlp_result[i]['up']['sscc']
                    mdlp_me = mdlp_result[i]['down']['sscc']
                    mdlp_me_owner = mdlp_result[i]['down']['owner_id']
                    childs = mdlp_result[i]['down']['childs']
                    # child_status = None
                    declared_warehouse_status = []
                    marked_status = []
                    for c in childs:
                        print(c)

                        if c['status'] == 'declared_warehouse':
                            declared_warehouse_status.append(c['sgtin'])
                        elif c['status'] == 'marked':
                            marked_status.append(c['sgtin'])
                    if declared_warehouse_status:
                        first_sgtin_status = 'declared_warehouse'
                    elif marked_status:
                        first_sgtin_status = 'marked'
                    else:
                        first_sgtin_status = childs[0]['status']

                    sgtins = []
                    for child in childs:
                        sgtins.append(child['sgtin'])
                    mdlp_parse_result_f[mdlp_me] = {'parent': mdlp_parent, 'owner_id': mdlp_me_owner,
                                                    'first_sgtin_status': first_sgtin_status,
                                                    'sgtin': sgtins,
                                                    'declared_warehouse_status': declared_warehouse_status,
                                                    'marked_status': marked_status}
                    i += 1
            return mdlp_parse_result_f


        case_hier_parse_mdlp = {}
        cases_to_check_on_mdlp = list(case_hier_dict_ant.keys())
        sn_limit = 10
        print('cases_to_check_on_mdlp: ', cases_to_check_on_mdlp)
        iterations = ceil(len(cases_to_check_on_mdlp) / sn_limit)
        i = 0

        while i < iterations:
            print(f"Processing {i} iteration...")
            will_skip = i * sn_limit
            till = will_skip + sn_limit
            print(f'Will skip: {will_skip}; till: {till}')
            cases_to_check_on_mdlp_tmp = cases_to_check_on_mdlp[will_skip:till]
            i += 1
            print('cases_to_check_on_mdlp_tmp: ', cases_to_check_on_mdlp_tmp)

            # set method delay:
            response = get_mdlp_sscc_full_hier(cases_to_check_on_mdlp_tmp, full_hierarchy_last_run)
            full_hierarchy_last_run = datetime.now()

            parsed = mdlp_response_parse_childs(response)
            case_hier_parse_mdlp.update(parsed)
            if i < iterations:
                print('Sleeping 30 sec...')
                time.sleep(30)

        print(f'cases_dict_mdlp: {case_hier_parse_mdlp}')
        logger.debug(f'cases_dict_mdlp: {case_hier_parse_mdlp}')

        print(f"{'#' * 50}")
        print(f"{'#' * 12}  Start compare process:  {'#' * 12}")
        print(f"{'#' * 50}")
        logger.debug(f"{'#' * 5}  Start compare process:")
        # print(f"Now when we have full hierarchy for cases and we could compare them:")
        queue_case = []
        pallet_911_generated = []
        pallet_exists_checked = []
        pallet_homogeneous_checked = []
        pallet_heterogeneous_checked = []
        mdlp_sscc_exists_checked = []

        parents = []

        for key, value in case_hier_dict_ant.items():
            print(f'key: {key}')
            logger.debug(f'key: {key}')
            print("let's try to compare:")
            case_hier_set_ant = set(case_hier_dict_ant[key]['sgtin'])
            case_parent_ant = case_hier_dict_ant[key]['parent']
            # if case_hier_parse_mdlp and case_hier_parse_mdlp[key]:
            if case_hier_parse_mdlp and key in case_hier_parse_mdlp:
                case_hier_set_mdlp = set(case_hier_parse_mdlp[key]['sgtin'])
                case_parent_mdlp = case_hier_parse_mdlp[key]['parent']
                first_sgtin_status = case_hier_parse_mdlp[key]['first_sgtin_status']
                declared_warehouse_status = case_hier_parse_mdlp[key]['declared_warehouse_status']
                marked_status = case_hier_parse_mdlp[key]['marked_status']
            else:
                case_hier_set_mdlp = set()
                case_parent_mdlp = []
                first_sgtin_status = ''
                declared_warehouse_status = []
                marked_status = []
            print(f'Antares parent: \t{case_parent_ant} , Case hier set: {case_hier_set_ant}')
            logger.debug(f'Antares parent: \t{case_parent_ant} , Case hier set: {case_hier_set_ant}')
            print(
                f'MDLP parent: \t\t{case_parent_mdlp}, First sgtin status is: {first_sgtin_status}, Case hier set: {case_hier_set_mdlp}')
            logger.debug(
                f'MDLP parent: \t\t{case_parent_mdlp}, First sgtin status is: {first_sgtin_status}, Case hier set: {case_hier_set_mdlp}')
            ant_minus_mdlp = case_hier_set_ant - case_hier_set_mdlp
            print(f'Antares - MDLP: {ant_minus_mdlp}')
            logger.debug(f'Antares - MDLP: {ant_minus_mdlp}')
            mdlp_minus_ant = case_hier_set_mdlp - case_hier_set_ant
            print(f'MDLP - Antares: {mdlp_minus_ant}')
            logger.debug(f'MDLP - Antares: {mdlp_minus_ant}')

            if queue_parallel:  # Auto parallel switcher:
                if case_parent_ant in parents:
                    queue_parallel = False
                    print(f'queue_parallel disabled in case of ant parent')
                    logger.debug(f'queue_parallel disabled in case of ant parent')
                else:
                    parents.append(case_parent_ant)

                if case_parent_mdlp in parents and case_parent_mdlp != key and case_parent_mdlp != case_parent_ant:  # !=key - mean that case have pallet, != antares parent - mean that we checked it on prev step
                    queue_parallel = False
                    print(f'queue_parallel disabled in case of mdlp parent')
                    logger.debug(f'queue_parallel disabled in case of mdlp parent')
                else:
                    parents.append(case_parent_ant)

            if ant_minus_mdlp:  # or mdlp_minus_ant
                print('We have to check if SGTINS have Case and that case have pallet on MDLP side')
                logger.debug('We have to check if SGTINS have Case and that case have pallet on MDLP side')
                sgtins_check = list(ant_minus_mdlp) + list(mdlp_minus_ant)
                sgtins_check_response = sgtins_by_list_request(sgtins_check)
                sgtins_check_cases, sgtins_in_cases = response_parser_sgtins(sgtins_check_response)
                # print(sgtins_check_cases)
                if sgtins_check_cases:
                    response_sscc_check = get_sscc_exists_mdlp_request(sgtins_check_cases)
                    result_sscc_check = response_parser_sscc_check(response_sscc_check)
                    print(f'result_sscc_check: {result_sscc_check}')
                    logger.debug(f'result_sscc_check: {result_sscc_check}')
                print(f'sgtins_in_cases count: {len(sgtins_in_cases)}, sgtins_in_cases: {sgtins_in_cases}')
                logger.debug(f'sgtins_in_cases count: {len(sgtins_in_cases)}, sgtins_in_cases: {sgtins_in_cases}')
                if sgtins_in_cases:
                    for k, v in result_sscc_check.items():
                        if v['parent_sscc']:
                            print(f'1) Generate 913 message to disaggregate case from MDLP parent.')
                            logger.debug(f'1) Generate 913 message to disaggregate case from MDLP parent.')
                            queue_case.append(operation_queue_generator(sorter_=1, type_=913, key_=key, childs_=k))
                    print(f'2) Generate 913 message to disaggregate incorrect sgtins from that case.')
                    logger.debug(f'2) Generate 913 message to disaggregate incorrect sgtins from that case.')
                    queue_case.append(
                        operation_queue_generator(sorter_=21, type_=913, key_=key, childs_=sgtins_in_cases))
                    for k, v in result_sscc_check.items():
                        if v['parent_sscc']:
                            print(f'3) Generate 914 message to aggregate case back to Pallet.')
                            logger.debug(f'3) Generate 914 message to aggregate case back to Pallet.')
                            queue_case.append(
                                operation_queue_generator(sorter_=3, type_=914, key_=key, childs_=k,
                                                          parent_=v['parent_sscc']))

            # 0) Have to generate 341 message for declared WH:
            if first_sgtin_status == 'declared_warehouse':

                metadata = get_metadata_for_342_doc(antares_parent=f'00{case_parent_ant}',
                                                    cases_all=sscc_all)

                if metadata:
                    doc_date, confirmation_num = metadata
                    print(f'On MDLP side case parent is: {case_parent_mdlp}')

                    if case_parent_mdlp:
                        if case_parent_mdlp != key:
                            print(f'11) Generate 913 message to disaggregate case from correct MDLP parent.')
                            logger.debug(f'11) Generate 913 message to disaggregate case from correct MDLP parent.')
                            queue_case.append(operation_queue_generator(sorter_=11, type_=913, key_=key, childs_=None))
                            case_parent_mdlp = False


                    print(f'7) Need to Generate 342 message to update status at first...')
                    logger.debug(f'7) Need to Generate 342 message to update status at first...')
                    print(
                        f'7) check status of sgtin which is same pallet but in different case and case not in sscc_all')
                    print(f'7) if status is in_circulation -> request documents for that sgtin and take 342 for it')
                    print(f'7) request metadata for that document to prepare 342 message...')
                    queue_case.append(
                        operation_queue_generator(sorter_=7, type_=342, key_=key, childs_=None, doc_date_=doc_date,
                                                  confirmation_num_=confirmation_num))
                else:
                    print('Some error here. Please check')
                    logger.debug('Some error here. Please check')
                    email_body.append(f'\n\nI could not found "doc_num" and "date" to prepare 342 document for {key}')
                    time.sleep(10)
            # 0) Have to generate 313 message for declared WH:
            if first_sgtin_status == 'marked':
                email_body.append(f'Need to Generate 313 message to update status at first...')
                print(f'7) Need to Generate 313 message to update status at first...')
                logger.debug(f'7) Need to Generate 313 message to update status at first...')
                metadata = get_metadata_for_313_doc(antares_parent=f'00{case_parent_ant}',
                                                    cases_all=sscc_all)
                if metadata:
                    doc_date, confirmation_num = metadata
                    if case_parent_mdlp:
                        if case_parent_mdlp != key:
                            print(f'11) Generate 913 message to disaggregate case from correct MDLP parent.')
                            logger.debug(f'11) Generate 913 message to disaggregate case from correct MDLP parent.')
                            queue_case.append(operation_queue_generator(sorter_=11, type_=913, key_=key, childs_=None))
                            case_parent_mdlp = False

                    queue_case.append(
                        operation_queue_generator(sorter_=71, type_=313, key_=key, childs_=None, doc_date_=doc_date,
                                                  confirmation_num_=confirmation_num))
            # 1) Check parents, if differ -> disaggregate:
            if case_parent_ant != case_parent_mdlp:
                if case_parent_mdlp == key:
                    case_parent_mdlp = False
                    print(f'Case do not have parent on MDLP side.')
                    logger.debug(f'Case do not have parent on MDLP side.')
                elif case_parent_mdlp:
                    print(f'11) Generate 913 message to disaggregate case from MDLP parent.')
                    logger.debug(f'11) Generate 913 message to disaggregate case from MDLP parent.')
                    queue_case.append(
                        operation_queue_generator(sorter_=11, type_=913, key_=key, childs_=case_parent_mdlp))
                    case_parent_mdlp = False
                    # message =
                    # here have to add message to operations dict
                else:
                    print(f'Do not have to disaggregate.')
                    logger.debug(f'Do not have to disaggregate.')
            else:
                print('Case parents are same.')
                logger.debug('Case parents are same.')

            # 2) Check down level, if differ generate messages:
            if ant_minus_mdlp or mdlp_minus_ant:
                if case_parent_mdlp:
                    print(f'11) Generate 913 message to disaggregate case from correct MDLP parent.')
                    logger.debug(f'11) Generate 913 message to disaggregate case from correct MDLP parent.')
                    queue_case.append(operation_queue_generator(sorter_=11, type_=913, key_=key, childs_=None))
                    case_parent_mdlp = False
                    print(f'Case do not have parent on MDLP side after my 913 message...')
                    logger.debug(f'Case do not have parent on MDLP side after my 913 message...')
                    if ant_minus_mdlp:
                        print(f'33) Generate 914 message to aggregate missed sgtins to that case.')
                        logger.debug(f'33) Generate 914 message to aggregate missed sgtins to that case.')
                        queue_case.append(
                            operation_queue_generator(sorter_=33, type_=914, key_=key, childs_=ant_minus_mdlp))
                    if mdlp_minus_ant:
                        print(f'21) Generate 913 message to disaggregate incorrect sgtins from that case.')
                        logger.debug(f'21) Generate 913 message to disaggregate incorrect sgtins from that case.')
                        queue_case.append(
                            operation_queue_generator(sorter_=21, type_=913, key_=key, childs_=mdlp_minus_ant))
                else:
                    if ant_minus_mdlp:
                        if case_hier_set_mdlp:
                            print(f'33) Generate 914 message to aggregate missed sgtins to that case.')
                            logger.debug(f'33) Generate 914 message to aggregate missed sgtins to that case.')
                            queue_case.append(
                                operation_queue_generator(sorter_=33, type_=914, key_=key, childs_=ant_minus_mdlp))
                        else:
                            print(f'42) Generate 911 message to create case with sgtins.')
                            logger.debug(f'42) Generate 911 message to create case with sgtins.')

                            queue_case.append(
                                operation_queue_generator(sorter_=42, type_=911, key_=key, childs_=ant_minus_mdlp))
                    if mdlp_minus_ant:
                        print(f'21) Generate 913 message to disaggregate incorrect sgtins from that case.')
                        logger.debug(f'21) Generate 913 message to disaggregate incorrect sgtins from that case.')
                        queue_case.append(
                            operation_queue_generator(sorter_=21, type_=913, key_=key, childs_=mdlp_minus_ant))
            # 3) Check if have to aggregate back to pallet:
            if not case_parent_mdlp and case_parent_ant:
                print('At first we have to know if Pallet is homogeneous')
                logger.debug('At first we have to know if Pallet is homogeneous')
                ant_par = f'00{case_parent_ant}'
                print(f'ant_par: {ant_par}')
                if ant_par in pallet_homogeneous_checked:
                    pallet_homogeneous_check = True
                    print(f'pallet_homogeneous_check True: {pallet_homogeneous_check}')
                elif ant_par in pallet_heterogeneous_checked:
                    pallet_homogeneous_check = False
                    print(f'pallet_homogeneous_check False: {pallet_homogeneous_check}')
                else:
                    pallet_homogeneous_check = check_sscc_homogeneous_antares(antares_parent=ant_par)
                    print(f'pallet_homogeneous_check checking: {pallet_homogeneous_check}')
                    if pallet_homogeneous_check:
                        pallet_homogeneous_checked.append(ant_par)
                    else:
                        pallet_heterogeneous_checked.append(ant_par)
                if pallet_homogeneous_check:
                    print(f'Checking if Pallet SSCC still present on MDLP side')
                    logger.debug(f'Checking if Pallet SSCC still present on MDLP side')
                    if case_parent_ant in mdlp_sscc_exists_checked:
                        mdlp_sscc_exists = True
                    else:
                        mdlp_sscc_exists = get_sscc_exists_mdlp(case_parent_ant)
                        mdlp_sscc_exists_checked.append(case_parent_ant)
                    if mdlp_sscc_exists:
                        print(f'53) Generate 914 message to aggregate case to correct Pallet.')
                        logger.debug(f'53) Generate 914 message to aggregate case to correct Pallet.')
                        queue_case.append(operation_queue_generator(sorter_=53, type_=914, key_=key, childs_=None,
                                                                    parent_=case_parent_ant))
                    else:
                        if case_parent_ant in pallet_911_generated:
                            print(
                                f'53) Generate 914 message to aggregate case to correct Pallet, because i created 911 earlier.')
                            logger.debug(
                                f'53) Generate 914 message to aggregate case to correct Pallet, because i created 911 earlier.')
                            queue_case.append(operation_queue_generator(sorter_=53, type_=914, key_=key, childs_=None,
                                                                        parent_=case_parent_ant))
                        else:
                            print(f'52) Generate 911 message to create Pallet with case')
                            logger.debug(f'52) Generate 911 message to create Pallet with case')
                            queue_case.append(operation_queue_generator(sorter_=52, type_=911, key_=key, childs_=None,
                                                                        parent_=case_parent_ant))
                            pallet_911_generated.append(case_parent_ant)
                else:
                    print(f'Antares pallet is heterogeneous and we do not need to aggregate case to it.')
                    logger.debug(f'Antares pallet is heterogeneous and we do not need to aggregate case to it.')
            print(f"{'_' * 50}")
            logger.debug(f"{'_' * 50}")

        print(f'queue_case: {queue_case}')
        logger.debug(f'queue_case: {queue_case}')

        # For manual runs at first we have to check:
        # if queue_case:
        #     if 'y' == input('Now you could stop process or press "y":'):
        #         print('GoGoGo...')
        #         logger.debug('GoGoGo...')
        # def check_accepted():
        #     # return random.choice([True, False, None])
        #     return random.choice([True, None])

        working = []
        error = []
        block_group_sorter = [52]
        queue_parallel_victim = []

        while len(queue_case) > 0:
            victim = queue_case.pop(0)
            # print(next_victim)
            for item, val in victim.items():
                if item in working:
                    if val['doc_sent'] and (not val['doc_accepted'] or val['doc_accepted'] is None):
                        # print(f'Checking document for {item} with document_id: ...')
                        time.sleep(2)
                        accepted = get_document_status_mdlp(val['document_id'])
                        print(f'Checked document_id for {item} Accepted: {accepted}')
                        logger.debug(f'Checked document_id for {item} Accepted: {accepted}')
                        if accepted:
                            val['doc_accepted'] = True
                            print(
                                f"Item {item} accepted and will DEL from queue, Sorter:{val['sorter']} Type:{val['type']}")
                            logger.debug(
                                f"Item {item} accepted and will DEL from queue, Sorter:{val['sorter']} Type:{val['type']}")
                            email_body.append(
                                f"Item {item} accepted. Type:{val['type']} Document_id:{val['document_id']} ")
                            for i, v in enumerate(working):
                                if v == item:
                                    working.pop(i)
                            if not queue_parallel:
                                queue_parallel_victim.pop(0)
                        elif not accepted:
                            if accepted is None:
                                # print(f'Not processed yet: {item}, val {val} will be added to the end of queue...')
                                queue_case.append(victim)
                                time.sleep(5)
                            else:
                                error.append(item)
                                val['doc_accepted'] = False
                                print(f'item: {item}, val: {val}')
                                logger.debug(f'item: {item}, val: {val}')
                                print(f'Some error faced with {item}. i could not go next now with it...')
                                logger.debug(f'Some error faced with {item}. i could not go next now with it...')
                                email_body.append(
                                    f"Item {item} REJECTED. Type:{val['type']} Document_id:{val['document_id']} ")
                                print(f'Email have to be generated here.')
                                if not queue_parallel:
                                    queue_parallel_victim.pop(0)

                    else:
                        if item not in error:
                            # print(f'Now that item: {item} with val: {val} will be added to the end of queue...')
                            queue_case.append(victim)
                        else:
                            print(f'Item with error faced: {item} It will not be added to queue back')
                            logger.debug(f'Item with error faced: {item} It will not be added to queue back')

                else:
                    # Parallel processing implementation:
                    if not queue_parallel and len(queue_parallel_victim) > 0:
                        print(f'Queue parallel sending disabled. Item will be added back to the end of queue.')
                        logger.debug(f'Queue parallel sending disabled. Item will be added back to the end of queue.')
                        queue_case.append(victim)
                        time.sleep(0.5)
                    else:
                        # blocking implementation:
                        # if i am 53 message but in queue present any 52 message a have to go to the end of queue:
                        if val['sorter'] // 10 == 5 and val['sorter'] not in block_group_sorter:
                            print(f"'Sorter is: {val['sorter']}'")
                            logger.debug(f"'Sorter is: {val['sorter']}'")
                            block_is = 0
                            for op in queue_case:
                                for key, value in op.items():
                                    if value['sorter'] in block_group_sorter:
                                        block_is = 1
                            print(f'block is: {block_is}')
                            logger.debug(f'block is: {block_is}')
                            if block_is == 1:
                                print('Add to the end of queue only...')
                                logger.debug('Add to the end of queue only...')
                                queue_case.append(victim)
                                time.sleep(2)
                            else:  # May send
                                print(f'Seems i could send...')
                                logger.debug(f'Seems i could send...')
                                print(f'Sending document for {item} to MDLP: {val}')
                                logger.debug(f'Sending document for {item} to MDLP: {val}')

                                message = val['message']
                                same_doc_id_sent = same_docs(queue=queue_case, doc_to_find=message)
                                if same_doc_id_sent:
                                    print('fake_send')
                                    logger.debug('fake_send')
                                    val['document_id'] = same_doc_id_sent
                                else:
                                    print('here we could send')
                                    upload = upload_xml_to_mdlp(thumbprint, message.decode('utf-8'))
                                    print(f'upload: {upload}')
                                    logger.debug(f"upload: {upload}")
                                    val['document_id'] = upload

                                working.append(item)
                                queue_parallel_victim.append(item)
                                queue_case.append(victim)
                                val['doc_sent'] = True
                                time.sleep(2)
                        else:
                            print(f'Sending document for {item} to MDLP: {val}')
                            logger.debug(f'Sending document for {item} to MDLP: {val}')
                            message = val['message']
                            same_doc_id_sent = same_docs(queue=queue_case, doc_to_find=message)
                            if same_doc_id_sent:
                                print('fake_send')
                                logger.debug('fake_send')
                                val['document_id'] = same_doc_id_sent
                            else:
                                print('here we could send')
                                upload = upload_xml_to_mdlp(thumbprint, message.decode('utf-8'))
                                print(f'upload: {upload}')
                                logger.debug(f"upload: {upload}")
                                val['document_id'] = upload

                            working.append(item)
                            queue_parallel_victim.append(item)
                            queue_case.append(victim)
                            val['doc_sent'] = True
                            time.sleep(2)

        if sscc_all:
            if error:
                email_subject = 'Error. Retry enabled. ' + email_subject
            else:
                email_subject = 'OK. ' + email_subject
            send_email_rg_rus(email_from, email_to, email_subject,
                              '\r\n'.join(email_body))  # body
            logger.debug(f"Email sent to {email_to}")
        timestamp = datetime.today().strftime('%Y%m%d%H%M%S')
        # Retry implementation:
        if retry_enabled and error and len(file_name) < 60:
            target_file_name = path.join(source_dir, file_name.replace('.txt', f'_{timestamp}.txt'))
            move(path.join(source_dir, file_name), target_file_name)
            logger.debug(f'File will be retried...')
        else:
            target_file_name = path.join(target_dir, file_name.replace('.txt', f'_{timestamp}.txt'))
            move(path.join(source_dir, file_name), target_file_name)
        # time.sleep(5)
