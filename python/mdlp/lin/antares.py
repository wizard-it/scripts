import pandas as pd
from sqlalchemy import create_engine, text as sql_text
import re

#engine_uri = "{}://{}:{}@{}/{}?driver={}".format(config.dialect, config.sqluser, config.sqlpassword, config.sqlhost, config.sqldatabase, config.driver)
#engine01 = create_engine(engine_uri, pool_pre_ping=True)

def get_sscc_hier_ant(serial_f,engine):
    serial_f = serial_f[2:]
    serial_f = serial_f[:(len(serial_f) - 1)]

    query = f"declare @serial as varchar(50) = '{serial_f}'  " \
            "SELECT parent.Id, parent.Serial, " \
            "concat(parent.Ntin,parent.Serial) as serial " \
            ",parent.CodingRuleId  " \
            ",	case " \
            "when child_level_1_NtinDef.CodingRuleId = 'GS1_SSCC' " \
            "then replace(replace(child_level_1_NtinDef.Ntin+child_level_1.Serial+dbo.CHKDGT(child_level_1_NtinDef.Id,child_level_1_NtinDef.Ntin,child_level_1.Serial, child_level_1_NtinDef.CodingRuleid),'(',''),')','') " \
            "else concat(child_level_1_NtinDef.Ntin,child_level_1.Serial) " \
            "end AS child_level_1_Serial" \
            ",child_level_1_NtinDef.CodingRuleId AS child_level_1_CodingRule  " \
            ",child_level_2_NtinDef.Ntin AS child_level_2_ntin  " \
            ",child_level_2.Serial AS child_level_2_Serial  " \
            ",child_level_2_NtinDef.CodingRuleId AS child_level_2_CodingRule  " \
            ",parent_q.up " \
            "FROM " \
            "	( " \
            "	select top 1 nd.Id		 " \
            "	,nd.Ntin		 " \
            "	,nd.CodingRuleId		 " \
            "	,(	SELECT Serial " \
            "		FROM [dbo].[Item] AS [t1]		         " \
            "		WHERE [t1].[Serial] = right(@serial,len(@serial)-len(nd.ntin)) " \
            "		AND [t1].[NtinId] = nd.id) as Serial		  " \
            "	from NtinDefinition as nd " \
            "	where ntin= left(@serial, len(ntin)) " \
            "	and CodingRuleId = 'GS1_SSCC'		  " \
            "	and EXISTS " \
            "		(" \
            "			SELECT 1 " \
            "			FROM [dbo].[Item] AS [t0]		         " \
            "			WHERE [t0].[Serial] = right(@serial,len(@serial)-len(nd.ntin))  " \
            "			AND [t0].[NtinId] = nd.id			" \
            "		)			" \
            ") AS parent  " \
            "JOIN item AS child_level_1 with (nolock) on child_level_1.ParentNtinId = parent.Id  " \
            "and child_level_1.ParentSerial = parent.Serial  " \
            "JOIN NtinDefinition AS child_level_1_NtinDef with (nolock)  " \
            "on child_level_1.NtinId = child_level_1_NtinDef.Id  " \
            "LEFT JOIN item AS child_level_2 with (nolock) ON child_level_2.ParentNtinId = child_level_1.NtinId  " \
            "and child_level_2.ParentSerial = child_level_1.Serial  " \
            "LEFT OUTER JOIN NtinDefinition AS child_level_2_NtinDef with (nolock)  " \
            "ON child_level_2.NtinId = child_level_2_NtinDef.Id " \
            "left join (	select i.NtinId,i.Serial " \
            "			,replace(replace(nd.Ntin+i.ParentSerial+dbo.CHKDGT(nd.Id,nd.Ntin,i.ParentSerial, nd.CodingRuleid),'(',''),')','') up " \
            "			from item i " \
            "			left join NtinDefinition nd on i.ParentNtinId=nd.Id) as parent_q on parent_q.NtinId=parent.Id and parent_q.Serial = parent.Serial " \
            "option (recompile)"
    with engine.connect() as connection:
        df = pd.read_sql_query(con=connection,
                               sql=sql_text(query))

    return df

def check_sscc_homogeneous_antares(antares_parent,engine):
    df = get_sscc_hier_ant(antares_parent,engine)
    # print(df)
    if not df.empty:
        cnt = df.child_level_2_ntin.value_counts()
        # print(cnt)
        return len(cnt.index) == 1



# anr_par = '00946054690009268406'
# print(check_sscc_homogeneous_antares(antares_parent=anr_par))
# sscc_template = r'^00(\d{17})'
# serial = '00959970013008318238'
# df = get_sscc_hierarchy(serial)
# print(df)
