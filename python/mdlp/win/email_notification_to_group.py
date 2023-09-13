# from email_notification import send_email_rg_rus
# Import smtplib for the actual sending function
import smtplib
# Here are the email package modules we'll need
from email.mime.image import MIMEImage
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

# from == the sender's email address
# to = the list of all recipients' email addresses
def send_email_rg_rus(email_from, email_to, email_subject, email_message):
    msg = MIMEMultipart()
    msg['Subject'] = email_subject
    msg['From'] = email_from
    msg['To'] = ', '.join(email_to)
    msg.attach(MIMEText(email_message, 'plain'))
    s = smtplib.SMTP('mail.rg-rus.ru')
    s.sendmail(email_from, email_to, msg.as_string())
    s.quit()


'''
from_ = 'bakhtovav@rg-rus.ru'
to_ = ['test_bakhtov@rg-rus.ru', 'bakhtovav@rg-rus.ru']
send_email_rg_rus(from_, to_, 'email_subject', 'email_message')
'''