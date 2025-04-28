# from lxml import etree
from datetime import datetime, timedelta
import config
import time
import logging
import logging.handlers as handlers
from logging import Formatter
from os import listdir, path
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



logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
logfile = "{}\\comparer.log".format(config.log_dir)
logHandler = handlers.RotatingFileHandler(logfile, maxBytes=50 ** 6, backupCount=5)
logHandler.setFormatter(Formatter(fmt='[%(asctime)s: %(levelname)s] %(message)s'))
logHandler.setLevel(logging.DEBUG)
logger.addHandler(logHandler)
logger.debug(f"{'#' * 20} Job started {'#' * 20}")

logger.debug(f'Thumbprint is: {config.user_cert_thumbprint}')
files = listdir(config.work_dir)

