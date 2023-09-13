import time
from lxml import etree
from lxml import etree as ET
from datetime import datetime, timedelta
import re

NS = 'http://www.w3.org/2001/XMLSchema-instance'
# WEB_NS = 'urn:tracelink:soap'
ns_map = {'xsi': NS}


def operation_queue_generator(sorter_, type_, key_, childs_, parent_=None, subject_id_='00000000223912', doc_date_=None, confirmation_num_=None):
    now_tz = datetime.today() - timedelta(hours=3)
    operation_date = now_tz.strftime('%Y-%m-%dT%H:%M:%S.001Z')
    if sorter_ == 11:  # Generate 913 message to disaggregate case from MDLP parent
        env = ET.Element('documents', version="1.36", nsmap=ns_map)
        body = ET.SubElement(env, 'unit_extract', action_id="913")
        child_1 = ET.SubElement(body, 'subject_id')
        child_1.text = subject_id_
        child_2 = ET.SubElement(body, 'operation_date')
        child_2.text = operation_date
        child_3 = ET.SubElement(body, 'content')
        child_3_1 = ET.SubElement(child_3, 'sscc')
        child_3_1.text = key_
        result = ET.tostring(env, pretty_print=True)
        # print(result)
    elif sorter_ == 1:  # Generate 913 message to disaggregate case from MDLP parent
        env = ET.Element('documents', version="1.36", nsmap=ns_map)
        body = ET.SubElement(env, 'unit_extract', action_id="913")
        child_1 = ET.SubElement(body, 'subject_id')
        child_1.text = subject_id_
        child_2 = ET.SubElement(body, 'operation_date')
        child_2.text = operation_date
        child_3 = ET.SubElement(body, 'content')
        child_3_1 = ET.SubElement(child_3, 'sscc')
        child_3_1.text = childs_
        result = ET.tostring(env, pretty_print=True)
        # print(result)
    elif sorter_ == 3:  # Generate 914 message to aggregate case to correct Pallet.
        env = ET.Element('documents', version="1.36", nsmap=ns_map)
        body = ET.SubElement(env, 'unit_append', action_id="914")
        child_1 = ET.SubElement(body, 'subject_id')
        child_1.text = subject_id_
        child_2 = ET.SubElement(body, 'operation_date')
        child_2.text = operation_date
        child_3 = ET.SubElement(body, 'sscc')
        child_3.text = parent_
        child_4 = ET.SubElement(body, 'content')
        child_5 = ET.SubElement(child_4, 'sscc')
        child_5.text = childs_
        result = ET.tostring(env, pretty_print=True)
        # print(result)
    elif sorter_ == 33:  # Generate 914 message to aggregate missed sgtins to that case.
        env = ET.Element('documents', version="1.36", nsmap=ns_map)
        body = ET.SubElement(env, 'unit_append', action_id="914")
        child_1 = ET.SubElement(body, 'subject_id')
        child_1.text = subject_id_
        child_2 = ET.SubElement(body, 'operation_date')
        child_2.text = operation_date
        child_3 = ET.SubElement(body, 'sscc')
        child_3.text = key_
        child_4 = ET.SubElement(body, 'content')
        for child in childs_:
            sgtin = ET.SubElement(child_4, 'sgtin')
            sgtin.text = child
        result = ET.tostring(env, pretty_print=True)
        # print(result)
    elif sorter_ == 21:  # Generate 913 message to disaggregate incorrect sgtins from that case.
        env = ET.Element('documents', version="1.36", nsmap=ns_map)
        body = ET.SubElement(env, 'unit_extract', action_id="913")
        child_1 = ET.SubElement(body, 'subject_id')
        child_1.text = subject_id_
        child_2 = ET.SubElement(body, 'operation_date')
        child_2.text = operation_date
        child_3 = ET.SubElement(body, 'content')
        for child in childs_:
            sgtin = ET.SubElement(child_3, 'sgtin')
            sgtin.text = child
        result = ET.tostring(env, pretty_print=True)
        # print(result)
    elif sorter_ == 42:  # Generate 911 message to create case with sgtins.
        env = ET.Element('documents', version="1.36", nsmap=ns_map)
        body = ET.SubElement(env, 'unit_pack', action_id="911")
        child_1 = ET.SubElement(body, 'subject_id')
        child_1.text = subject_id_
        child_3 = ET.SubElement(body, 'sscc')
        child_3.text = key_
        child_2 = ET.SubElement(body, 'operation_date')
        child_2.text = operation_date
        child_4 = ET.SubElement(body, 'content')
        for child in childs_:
            sgtin = ET.SubElement(child_4, 'sgtin')
            sgtin.text = child
        result = ET.tostring(env, pretty_print=True)
        # print(result)
    elif sorter_ == 52:  # Generate 911 message to create Pallet with case.
        # Нужно учесть ,что паллет может создаться одним из моих сообщений в очереди ранее... и у нас получится два 911 на один паллет
        env = ET.Element('documents', version="1.36", nsmap=ns_map)
        body = ET.SubElement(env, 'unit_pack', action_id="911")
        child_1 = ET.SubElement(body, 'subject_id')
        child_1.text = subject_id_
        child_3 = ET.SubElement(body, 'sscc')
        child_3.text = parent_
        child_2 = ET.SubElement(body, 'operation_date')
        child_2.text = operation_date
        child_4 = ET.SubElement(body, 'content')
        child_5 = ET.SubElement(child_4, 'sscc')
        child_5.text = key_
        result = ET.tostring(env, pretty_print=True)
        # print(result)
    elif sorter_ == 53:  # Generate 914 message to aggregate case to correct Pallet.
        env = ET.Element('documents', version="1.36", nsmap=ns_map)
        body = ET.SubElement(env, 'unit_append', action_id="914")
        child_1 = ET.SubElement(body, 'subject_id')
        child_1.text = subject_id_
        child_2 = ET.SubElement(body, 'operation_date')
        child_2.text = operation_date
        child_3 = ET.SubElement(body, 'sscc')
        child_3.text = parent_
        child_4 = ET.SubElement(body, 'content')
        child_5 = ET.SubElement(child_4, 'sscc')
        child_5.text = key_
        result = ET.tostring(env, pretty_print=True)
        # print(result)
    elif sorter_ == 7:  # Generate 342 message for items.
        env = ET.Element('documents', version="1.36", nsmap=ns_map)
        body = ET.SubElement(env, 'release_in_circulation', action_id="342")
        child_1 = ET.SubElement(body, 'subject_id')
        child_1.text = subject_id_
        child_2 = ET.SubElement(body, 'operation_date')
        child_2.text = operation_date
        release_info = ET.SubElement(body, 'release_info')
        doc_date = ET.SubElement(release_info, 'doc_date')
        doc_date.text = doc_date_
        confirmation_num = ET.SubElement(release_info, 'confirmation_num')
        confirmation_num.text = confirmation_num_
        signs = ET.SubElement(body, 'signs')
        sscc = ET.SubElement(signs, 'sscc')
        sscc.text = key_
        result = ET.tostring(env, pretty_print=True)
        # print(result)
    elif sorter_ == 71:  # Generate 313 message for items.
        env = ET.Element('documents', version="1.36", nsmap=ns_map)
        body = ET.SubElement(env, 'register_product_emission', action_id="313")
        child_1 = ET.SubElement(body, 'subject_id')
        child_1.text = subject_id_
        child_2 = ET.SubElement(body, 'operation_date')
        child_2.text = operation_date
        release_info = ET.SubElement(body, 'release_info')
        doc_date = ET.SubElement(release_info, 'doc_date')
        doc_date.text = doc_date_
        confirmation_num = ET.SubElement(release_info, 'confirmation_num')
        confirmation_num.text = confirmation_num_
        signs = ET.SubElement(body, 'signs')
        sscc = ET.SubElement(signs, 'sscc')
        sscc.text = key_
        result = ET.tostring(env, pretty_print=True)
        # print(result)
    else:
        print('Unknown sorter input...')
        return
    operation = {
        key_: {"sorter": sorter_,
               'type': type_,
               'message': result,
               'document_id': None,
               'doc_sent': False,
               'doc_accepted': None}}
    time.sleep(1)  # We have to sleep to have different time in reports
    return operation


operation_date_template = r"(?m)(^\s+\<operation_date>\d{4}\-\d{2}\-\d{2}T\d{2}\:\d{2}\:\d{2}\.\d{3}Z\<\/operation_date>)"


def same_docs(queue, doc_to_find):
    doc_to_find = doc_to_find.decode()
    doc_to_find_replaced = re.sub(operation_date_template, '', doc_to_find)
    for q in queue:
        for key_, val_ in q.items():
            if val_['document_id']:
                doc = val_['message'].decode()
                if doc_to_find_replaced == re.sub(operation_date_template, '', doc):
                    return val_['document_id']

# we have to do check if we try to sent document with highter operation date than in queue not sent docs with same operation type
# or we have to generate document for group
# or we have to end file processing to check it again with next_iteration

# result = operation_queue_generator(sorter_=11, type_=913, key_='0094600012345', childs_=None, parent_=None)
# childs = {'046054690007819364022402519', '046054690007811076613516330', '046054690007813004347647759', '046054690007816127082869051', '046054690007819124710205417', '046054690007814827519618606', '046054690007813263492772074'}
# # for i in childs:
# #     print(i)
# # result = operation_queue_generator(sorter_=33, type_=914, key_='0094600012345', childs_=childs, parent_=None)
# # result = operation_queue_generator(sorter_=21, type_=913, key_='0094600012345', childs_=childs, parent_=None)
# # result = operation_queue_generator(sorter_=42, type_=911, key_='0094600012345', childs_=childs, parent_=None)
# result = operation_queue_generator(sorter_=52, type_=911, key_='0094600012345', childs_=childs, parent_='0094600012349')
# print(result)
