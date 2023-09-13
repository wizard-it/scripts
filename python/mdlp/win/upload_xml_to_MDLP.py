from token_request import token_request, token
from datetime import datetime, timedelta
import requests
import json
import win32com.client
import datetime
import base64
import uuid


def upload_xml_to_mdlp(thumbprint, document):
    api_url = "http://127.0.0.1:18080"
    CADES_BES = 1
    CADES_DEFAULT = 0
    CAPICOM_ENCODE_BASE64 = 0
    CAPICOM_CURRENT_USER_STORE = 2
    CAPICOM_MY_STORE = 'My'
    CAPICOM_STORE_OPEN_MAXIMUM_ALLOWED = 2

    oStore = win32com.client.Dispatch("CAdESCOM.Store")
    oStore.Open(CAPICOM_CURRENT_USER_STORE, CAPICOM_MY_STORE, CAPICOM_STORE_OPEN_MAXIMUM_ALLOWED)
    for val in oStore.Certificates:
        if val.Thumbprint == thumbprint.upper():
            oCert = val
    oStore.Close

    oSigner = win32com.client.Dispatch("CAdESCOM.CPSigner")
    oSigner.Certificate = oCert
    oSigningTimeAttr = win32com.client.Dispatch("CAdESCOM.CPAttribute")
    oSigningTimeAttr.Name = 0
    oSigningTimeAttr.Value = datetime.datetime.now()
    oSigner.AuthenticatedAttributes2.Add(oSigningTimeAttr)

    oSignedData = win32com.client.Dispatch("CAdESCOM.CadesSignedData")
    oSignedData.ContentEncoding = 1
    message = document
    message_bytes = message.encode('ascii')
    base64_bytes = base64.b64encode(message_bytes)
    base64_message = base64_bytes.decode('ascii')
    oSignedData.Content = base64_message
    sSignedData = oSignedData.SignCades(oSigner, CADES_BES, False, CAPICOM_ENCODE_BASE64)

    documents_send = f"{api_url}/api/v1/documents/send"
    payload = json.dumps({
        "document": oSignedData.Content,
        "sign": sSignedData,
        "request_id": str(uuid.uuid4()),
        "bulk_processing": "false"
    })
    headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        f'Authorization': f'token {token()}'
    }
    # print(document)
    # print(payload)
    response = requests.request("POST", documents_send, headers=headers, data=payload)
    # print(response.text)
    document_id = json.loads(response.text)
    return document_id['document_id']

