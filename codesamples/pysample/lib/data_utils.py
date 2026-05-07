import pickle
import pandas as pd
import numpy as np
import re
import os
from pathlib import Path
from scipy import stats

# 运行时存储：由 export_plot_data 写入，由 LLM 函数读取
data_export_mapping = []
data_export_storage = {}

# 2026.03.23 删减目录

# 全局数据收集字典
data_export_mapping = []
data_export_storage = {}  # 存储所有数据框

def export_plot_data(df, title, pic_name, data_dir='inter_data'):
    """
    收集绘图数据到内存中，不立即导出文件

    参数：
    - df: 用于绘图的数据框
    - title: 图表标题
    - pic_name: 图片名称
    - data_dir: 数据导出目录（保留参数但不使用）
    """
    import re

    # 清理标题中的特殊字符，生成合法的sheet名称
    clean_title = re.sub(r'[\\/:*?"<>|]', '_', title)
    clean_title = clean_title.strip()

    # 处理重复标题：检查是否已存在相同标题
    existing_titles = [item['标题'] for item in data_export_mapping]
    title_count = existing_titles.count(title)

    if title_count > 0:
        # 如果标题重复，添加序号
        sheet_name = f"{clean_title}_{title_count + 1}"
    else:
        sheet_name = clean_title

    # Excel sheet名称最长31字符
    if len(sheet_name) > 31:
        sheet_name = sheet_name[:28] + f"_{title_count + 1}" if title_count > 0 else sheet_name[:31]

    # 存储数据框到内存
    try:
        if isinstance(df, pd.DataFrame):
            data_export_storage[sheet_name] = df.copy()
        elif isinstance(df, pd.Series):
            data_export_storage[sheet_name] = df.to_frame()
        else:
            print(f"警告：无法导出数据类型 {type(df)} for {title}")
            return None
    except Exception as e:
        print(f"收集数据失败 {title}: {e}")
        return None

    # 记录映射关系（已注释 -- Excel导出功能不再需要）
    # data_export_mapping.append({
    #     '标题': title,
    #     'sheet名称': sheet_name,
    #     '图片名称': pic_name
    # })

    return sheet_name


def repo_level_info():
    return {
        # 固定值、常数的写法
        'province': {
            'level_name': lambda x: '自治区',
            'g_by': lambda x: 'city',
            'g_by_name': lambda x: '盟市',
            'list_lower_level': lambda x: ['呼和浩特市','包头市','乌海市','赤峰市','通辽市','鄂尔多斯市','呼伦贝尔市','巴彦淖尔市','乌兰察布市','兴安盟','锡林郭勒盟','阿拉善盟'],
            'df_basic': lambda x: x['df_basic_ori'].copy(),
            'df_sch': lambda x: x['df_sch_ori'].copy(),
            'df_tea': lambda x: x['df_tea_ori'].copy(),
            'df_gro': lambda x: x['df_gro_ori'].copy(),
            'df_stu': lambda x: x['df_stu_ori'].copy(),
            'df_files': lambda x: x['df_files_ori'].copy(),
        },
        # 有参数的写法
        'city': {
            # 'city_name': lambda x: x['city_name'],
            # 'level_name': lambda x: 'city',
            'city_name': lambda x: x['city_name'],
            'level_name': lambda x: x['city_name'],
            'g_by': lambda x: 'school',
            'g_by_name': lambda x: '学校',
            # 'level_name': 'city',
            # 'g_by': 'school',
            # 'g_by_name': '学校',
            'list_lower_level': lambda x: x['df_basic_ori'].loc[x['df_basic_ori']['city'] == x['city_name'], 'school'].sort_values(ascending=False).drop_duplicates().values.tolist(),
            'df_basic': lambda x: x['df_basic_ori'][x['df_basic_ori']['city'] == x['city_name']].copy(),
            'df_sch': lambda x: x['df_sch_ori'][x['df_sch_ori']['city'] == x['city_name']].copy(),
            'df_tea': lambda x: x['df_tea_ori'][x['df_tea_ori']['city'] == x['city_name']].copy(),
            'df_gro': lambda x: x['df_gro_ori'][x['df_gro_ori']['city'] == x['city_name']].copy(),
            'df_stu': lambda x: x['df_stu_ori'][x['df_stu_ori']['city'] == x['city_name']].copy(),
            'df_files': lambda x: x['df_files_ori'][x['df_files_ori']['city'] == x['city_name']].copy(),
        },
    }

def get_level_info(level_key, **x):
    # 解包
    da = repo_level_info()
    result_da = da[level_key]
    # 从解包结果中取数
    level_name = result_da['level_name'](x)
    g_by = result_da['g_by'](x)
    g_by_name = result_da['g_by_name'](x)
    list_lower_level = result_da['list_lower_level'](x)
    df_basic = result_da['df_basic'](x)
    df_sch = result_da['df_sch'](x)
    df_tea = result_da['df_tea'](x)
    df_gro = result_da['df_gro'](x)
    df_stu = result_da['df_stu'](x)
    df_files = result_da['df_files'](x)
    # if level_key == 'city':
    #     city_name = result_da['city_name'](x)
    #     return level_name, g_by, g_by_name, list_lower_level, df_basic, df_sch, df_tea, df_gro, df_stu, df_files, level_key, city_name
    # else:
    return level_name, g_by, g_by_name, list_lower_level, df_basic, df_sch, df_tea, df_gro, df_stu, df_files, level_key

def yuchuli_df(df):
    df = df.drop(['问题id','字段id','维度id','区域维度','维度名称','状态','映射表-题id','映射表-题号','映射表-字段id','维度表-题号','维度表-题id','维度表-维度id',],axis=1)
    df = df.rename(columns={
        '用户维度':'user_id','学科维度':'subject','年级维度':'grade', '学期维度':'sem','映射表-字段标题':'alternative',
    })

    df.loc[(df['field_value'].astype(str)=='1')&(df['alternative'].str.contains(r'其他，|其它，',na=False)), 'alternative'] = '其他'
    return df


# 文本函数
def para_series(se, str_unit='学校',danyuan='所'):
    return '，'.join([f'{i}{str_unit}{v}{danyuan}' for i,v in se.items()]) + '。'

# 找单列异常值函数
from scipy import stats
import numpy as np
def mark_ouliers(df,col,threshold=2):
    # 计算Z-score
    df[col+'_z_scores'] = np.abs(stats.zscore(df[col]))

    # 设置阈值（通常为2或3）

    # 标记离群值
    df.loc[(df[col+'_z_scores']>threshold), col+'_异常值'] = '异常值'

    df = df.drop([col+'_z_scores'], axis=1)
    return df
