import win32com.client
import os, sys
import json
import datetime
# from datetime import timedelta
import base64


def token_request():
    CADES_BES = 1
    CADES_DEFAULT = 0
    CAPICOM_ENCODE_BASE64 = 0
    CAPICOM_CURRENT_USER_STORE = 2
    CAPICOM_MY_STORE = 'My'
    CAPICOM_STORE_OPEN_MAXIMUM_ALLOWED = 2

    oStore = win32com.client.Dispatch("CAdESCOM.Store")
    oStore.Open(CAPICOM_CURRENT_USER_STORE, CAPICOM_MY_STORE, CAPICOM_STORE_OPEN_MAXIMUM_ALLOWED)
    for val in oStore.Certificates:
        # print(val.SerialNumber)
        # print(val.Thumbprint)
        # if val.SerialNumber == '1EB909D100010003BCA1':
        if val.Thumbprint == ('559F01F3A05A8505B4C18968E4570FC51A3FC196').upper():
            oCert = val
    oStore.Close
    # print(oCert)

    oSigner = win32com.client.Dispatch("CAdESCOM.CPSigner")
    oSigner.Certificate = oCert
    oSigningTimeAttr = win32com.client.Dispatch("CAdESCOM.CPAttribute")
    oSigningTimeAttr.Name = 0
    oSigningTimeAttr.Value = datetime.datetime.now()
    oSigner.AuthenticatedAttributes2.Add(oSigningTimeAttr)

    url = "http://127.0.0.1:18080/api/v1/auth"

    params = {
        'client_id': 'f20f1baf-6117-4a4a-a277-7ecfe9fd8e56',
        'client_secret': '29735216-7d01-4311-9883-0e27c25a8678',
        'user_id': '559F01F3A05A8505B4C18968E4570FC51A3FC196',
        'auth_type': 'SIGNED_CODE'
    }
    win_http = win32com.client.Dispatch('WinHTTP.WinHTTPRequest.5.1')
    win_http.Open("POST", url, False)
    win_http.SetRequestHeader("Content-Type", "application/json;charset=UTF-8")
    win_http.SetRequestHeader("Accept", "application/json;charset=UTF-8")

    win_http.Send(json.dumps(params))
    win_http.WaitForResponse()
    # print(win_http.ResponseText)
    items = json.loads(win_http.ResponseText)
    CodeAuth = items['code']

    oSignedData = win32com.client.Dispatch("CAdESCOM.CadesSignedData")
    oSignedData.ContentEncoding = 1
    message = CodeAuth
    message_bytes = message.encode('ascii')
    base64_bytes = base64.b64encode(message_bytes)
    base64_message = base64_bytes.decode('ascii')
    oSignedData.Content = base64_message
    # print(CADES_BES)
    sSignedData = oSignedData.SignCades(oSigner, CADES_BES, False, CAPICOM_ENCODE_BASE64)


    url = "http://127.0.0.1:18080/api/v1/token"
    paramskey = {
      'code': CodeAuth,
      'signature': sSignedData
    }
    # print(json.dumps(paramskey))
    win_http.Open("POST", url, False)
    win_http.SetRequestHeader("Content-Type", "application/json;charset=UTF-8")
    win_http.SetRequestHeader("Accept", "application/json;charset=UTF-8")
    win_http.Send(json.dumps(paramskey))
    win_http.WaitForResponse()
    token = win_http.ResponseText
    if token:
        # print(token)
        return token


def token():
    with open(".\\token.json", "r", encoding="utf-8") as f:
        try:
            token_response_file = json.load(f)
            token_response_file = json.loads(token_response_file)
            life_time = token_response_file['life_time']
        except ValueError:
            life_time = 10
        file_creation_date = os.path.getmtime(".\\token.json")
        if datetime.datetime.fromtimestamp(file_creation_date) < (datetime.datetime.now() - datetime.timedelta(seconds=life_time)):
            token_response = token_request()
            with open(".\\token.json", "w", encoding="utf-8") as f:
                json.dump(token_response, f, ensure_ascii=False)
            token_response = json.loads(token_response)
            token_alive = token_response['token']
        else:
            # print("Is life")
            token_alive = token_response_file['token']
    # print(token_alive)
    return token_alive
