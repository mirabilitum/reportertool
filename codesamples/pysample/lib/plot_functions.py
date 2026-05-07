import matplotlib
import textwrap
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.colors import LinearSegmentedColormap
from matplotlib.patches import Patch
import matplotlib.ticker as ticker
import matplotlib.ticker as mticker
import matplotlib.patheffects as path_effects
from mpl_toolkits.axes_grid1 import make_axes_locatable
import matplotlib.font_manager as fm
import numpy as np
import seaborn as sns
import base64
from io import BytesIO
import gc
import sys
import os
import re
import matplotlib.patheffects as pe
from lib.data_utils import para_series,export_plot_data

# 字体配置
plt.rcParams["font.sans-serif"] = ["SimHei"]
plt.rcParams["axes.unicode_minus"] = False

# adjust_text 支持（可选）
try:
    sys.path.insert(0, r'D:\Starfish-W\Coding\works0--graph')
    from N001_1_adjust_text import adjust_text
except Exception:
    pass


# 绘图函数
# 选择题：
def colors_choice(n):
    # if n == len(list_lower_level):
    #     return sns.color_palette("hls",len(list_lower_level))
    if n ==7:
        return ['#1b4551','#4a706f','#629991','#99af86','#ddc781','#dda976','#c87b5e'] 
    if n ==6:
        return ['#4a706f','#629991','#99af86','#ddc781','#dda976','#c87b5e'] 
    if n ==5:
        return ['#4a706f','#629991',"#ddc781",'#dda976','#c87b5e'] 
    if n ==4:
        return ['#629991','#ddc781','#99af86','#c87b5e'] 
    if n ==3:
        return ['#629991','#ddc781','#c87b5e']
    if n ==2:
        return ['#629991','#c87b5e'] 
    if n ==1:
        return ['#c87b5e',] 
    
# 分类色
def colors_heatmap(n):
    if n ==1:
        return ['#dae6f1','#b3cede','#78aac8','#4884af','#225b91'] 
    if n ==2:
        return ['#ddeed9','#b3d7ae','#7dba7f','#44935b','#196937'] 
    if n ==3:
        return ['#F5F5F5','#E0E0E0','#FF6B6B','#D64545','#8B0000'] 

# 渐变色
def colors_map_trans(n):
    colors_map = colors_heatmap(n)
    colors_map_value = LinearSegmentedColormap.from_list("custom_cmap", colors=colors_map)
    return colors_map_value

plt.rcParams["font.sans-serif"] = ["SimHei"]
plt.rcParams["axes.unicode_minus"] = False

PLOT_TITLE_ENABLED = True


def set_plot_title_enabled(enabled: bool = True) -> None:
    """Global switch for plot titles in this module."""
    global PLOT_TITLE_ENABLED
    PLOT_TITLE_ENABLED = bool(enabled)


def get_plot_title_enabled() -> bool:
    """Get current global title switch status."""
    return PLOT_TITLE_ENABLED


def _title_text(text) -> str:
    """Return title text or empty string based on global switch."""
    if not PLOT_TITLE_ENABLED:
        return ""
    return "" if text is None else str(text)


import base64
from io import BytesIO
import matplotlib.pyplot as plt
import gc   # 垃圾回收

def encode_pic():
    buffer = BytesIO()
    fig = plt.gcf()  # 获取当前激活的 Figure 对象

    plt.savefig(buffer, bbox_inches='tight', format='png')
    buffer.seek(0)
    image_data = buffer.read() 

    base64_encoded_image = base64.b64encode(image_data).decode('utf-8')
    pic_code = f'data:image/png;base64,{base64_encoded_image}'  

    # ===== 清理内存 =====
    buffer.close()        # 关闭 BytesIO
    plt.close(fig)        # 关闭当前 Figure
    del fig, buffer       # 删除引用
    gc.collect()          # 强制垃圾回收

    return pic_code

def make_autopct(labels, values, decimal_place=1):
    total = sum(values)
    counter = {'i': 0}  # 用字典包装以便闭包可以修改

    def my_autopct(pct):
        if pct <= 0:
            return ""
        i = counter['i']
        label = labels[i]
        value = values[i]
        counter['i'] += 1

        return f"{label}: {value}（{pct:.{decimal_place}f}%）"

    return my_autopct

    
# 饼图
def mpl_pie(se, title, note_x=0, note_y=0, note='', legend_ncol=0, decimal_place=2, show_pic=True, encoded_pic=True):
    # 类别
    
    se = se.rename('count').to_frame()
    se['perc'] = se['count'].div(se['count'].sum())
    
    fig = plt.figure(figsize=(12, 6))
    ax1 = fig.add_subplot(111)

    t_labels = [f"{i}，{item_row['count']:.0f}，{item_row['perc']*100:.{decimal_place}f}%" for i, item_row in se.iterrows()]

    wedges, texts, autotexts= ax1.pie(
        se['count'],
        labels=t_labels,
        # labeldistance=0.9,
        autopct='',
        startangle=0,
        counterclock=True,
        colors=colors_choice(se.shape[0]),
        textprops={'fontsize': 12}
    )
    if legend_ncol>0:
        legend_handles = [Patch(color=colors_choice(len(se))[n], label=x) for n,x in enumerate(se.index)]
        ax1.legend(handles=legend_handles,loc='upper center',bbox_to_anchor=(0.5,0),ncol=legend_ncol,fontsize=12,frameon=False,)
    plt.title(title, fontsize=14,y=1.1)
    if note != '':
        fig.text(x=note_x, y= 0,s=note,fontsize=11, ha='left',va='bottom')
    plt.axis('equal')

    # 存为base64码并展示
    if show_pic == True:
        plt.show()
    if encoded_pic == True:
        return encode_pic()
    
# 堆叠柱状图
# def mpl_stack_bar_mul_perc(df,title,pic_name,colors,legend_ncol,note='',note_x=0.2,note_y=0,w = 0.6,text_size=12,decimal_place=0,wrap_l=10,encoded_pic=False,show_pic=True,special=0):
#     export_plot_data(df, title, pic_name)
#     xlabel_h = max(s.count('\n') for s in df.index)+1
#     # # fig_h = 4+fig_legend
#     # fig_h = 4+xlabel_h
#     fig = plt.figure(figsize=(16, 6))
#     ax1 = fig.add_subplot(111)

#     bo_m = np.zeros(len(df.index))
#     for c,col in enumerate(df.columns):
#         if sum(df[col])>0:
#             bars_1 = ax1.bar(df.index, df[col], width=w, bottom=bo_m, color=colors[c], label=col)
#             for r,row in enumerate(df.index):
#                 v_1 = df[col][r]
#                 if special==0:
#                     if v_1>0:
#                         ax1.text(row, bo_m[r]+v_1/2,  f'{v_1*100:.{decimal_place}f}%', ha='center', va='center', fontsize=text_size, weight='bold')
#                 else:
#                     if v_1>0 and(len(row)<5):
#                         ax1.text(row, bo_m[r]+v_1/2,  f'{v_1*100:.{decimal_place}f}%', ha='center', va='center', fontsize=text_size, weight='bold')
                
#             bo_m = bo_m+ df[col]
#         else:
#             continue

#     # 调整x轴刻度标签的位置和方向
#     ax1.tick_params(axis='x', which='both', left=False, right=False, labelleft=False, labelright=False)
#     ax1.tick_params(axis='y', which='both', top=False, bottom=True, labeltop=False, labelbottom=False)
#     ax1.tick_params(axis='x', labelsize=text_size)       # 仅修改 X 轴刻度文本的字号
#     ax1.yaxis.set_major_formatter(mticker.PercentFormatter(1))# 设置 Y 轴为百分比格式
#     ax1.tick_params(axis='y', labelsize=text_size)            # 调整刻度文本的字号

#     ax1.set_xlim( -0.5, len(df)-0.5)
#     ax1.set_ylim( -0.05, 1.05)

#     # 设置图例位置和样式
#     legend_handles = []
#     for c,col in enumerate(df.columns):
#         wrapped_text = '\n'.join(textwrap.wrap(col, width=wrap_l))
#         p_t = Patch(color=colors[c], label=wrapped_text)
#         legend_handles.append(p_t)

#     ax1.legend(handles=legend_handles[::-1],bbox_to_anchor=(0.5,-0.05*xlabel_h),loc='upper center', ncol=legend_ncol,frameon=False,fontsize=text_size)
#     ax1.set_title(title, fontsize=text_size+2,weight='bold',y=1.1)#+0.05*int(len(df.columns)/legend_ncol))
#     if note != '':
#         fig.text(x=note_x, y= note_y,s=note,fontsize=11, ha='left',va='bottom')

#     # 图片保存到figures文件夹
#     plt.savefig(f"figures/{pic_name}.png", bbox_inches='tight')
#     # 存为base64码并展示
#     if show_pic == True:
#         plt.show()
#     if encoded_pic == True:
#         return encode_pic()
def mpl_stack_bar_mul_perc(df,title,pic_name,colors,legend_ncol,note='',note_x=0.2,note_y=0,w = 0.6,text_size=12,decimal_place=0,wrap_l=10,encoded_pic=False,show_pic=True):
    export_plot_data(df, title, pic_name)
    xlabel_h = max(s.count('\n') for s in df.index)+1
    # # fig_h = 4+fig_legend
    # fig_h = 4+xlabel_h
    fig = plt.figure(figsize=(16, 6))
    ax1 = fig.add_subplot(111)

    bo_m = np.zeros(len(df.index))
    for c,col in enumerate(df.columns):
        if sum(df[col])>0:
            bars_1 = ax1.bar(df.index, df[col], width=w, bottom=bo_m, color=colors[c], label=col)
            for r,row in enumerate(df.index):
                v_1 = df[col][r]
                if v_1>0:
                    ax1.text(row, bo_m[r]+v_1/2,  f'{v_1*100:.{decimal_place}f}%', ha='center', va='center', fontsize=text_size, weight='bold')
            bo_m = bo_m+ df[col]
        else:
            continue

    # 调整x轴刻度标签的位置和方向
    ax1.tick_params(axis='x', which='both', left=False, right=False, labelleft=False, labelright=False)
    ax1.tick_params(axis='y', which='both', top=False, bottom=True, labeltop=False, labelbottom=False)
    ax1.tick_params(axis='x', labelsize=text_size)       # 仅修改 X 轴刻度文本的字号
    ax1.yaxis.set_major_formatter(mticker.PercentFormatter(1))# 设置 Y 轴为百分比格式
    ax1.tick_params(axis='y', labelsize=text_size)            # 调整刻度文本的字号

    ax1.set_xlim( -0.5, len(df)-0.5)
    ax1.set_ylim( -0.05, 1.05)

    # 设置图例位置和样式
    legend_handles = []
    for c,col in enumerate(df.columns):
        wrapped_text = '\n'.join(textwrap.wrap(col, width=wrap_l))
        p_t = Patch(color=colors[c], label=wrapped_text)
        legend_handles.append(p_t)

    ax1.legend(handles=legend_handles[::-1],bbox_to_anchor=(0.5,-0.05*xlabel_h),loc='upper center', ncol=legend_ncol,frameon=False,fontsize=text_size)
    ax1.set_title(_title_text(title), fontsize=text_size+2,weight='bold',y=1.04)#+0.05*int(len(df.columns)/legend_ncol))
    if note != '':
        fig.text(x=note_x, y= note_y,s=note,fontsize=11, ha='left',va='bottom')
    
    # 图片保存到figures文件夹
    plt.savefig(f"figures/{pic_name}.png", bbox_inches='tight')
    # 存为base64码并展示
    if show_pic == True:
        plt.show()
    if encoded_pic == True:
        return encode_pic()
    
# 多条折线图：占比
def mpl_line_mul_perc(df, title, pic_name, legend_ncol, colors, note='', note_x=0.2, note_y=0,
                      text_size=12, decimal_place=0, encoded_pic=False, show_pic=True):
    export_plot_data(df, title, pic_name)

    df_plot = df.copy()
    df_plot.index = ['\n'.join(textwrap.wrap(s, 13)) if len(s)>13 else s for s in df_plot.index]
    
    fig = plt.figure(figsize=(12, 8))
    ax1 = fig.add_subplot(111)

    list_te = []
    for c, col in enumerate(df_plot.columns):
        ax1.plot(df_plot.index, df_plot[col], color=colors[c], linewidth=1, markersize=15, marker='.', label=col)
        for r in range(len(df_plot.index)):
            v_1 = df_plot[col].iloc[r]
            li_1 = ax1.text(
                r, v_1, f'{v_1*100:.{decimal_place}f}%',
                ha='left', va='bottom', color=colors[c], fontsize=text_size, label=col
            )
            list_te.append(li_1)

    adjust_text(list_te, force_pull=(0.01, 0.1))

    # 不显示 xy 轴标签名字
    ax1.set_xlabel('')
    ax1.set_ylabel('')

    # x轴标签显示并竖直
    ax1.tick_params(axis='x', which='both', bottom=True, top=False, labelbottom=True, labeltop=False)
    ax1.tick_params(axis='y', which='both', left=True, right=False, labelleft=True, labelright=False)
    ax1.tick_params(axis='x', labelsize=text_size)
    ax1.tick_params(axis='y', labelsize=text_size)
    plt.setp(ax1.get_xticklabels(), rotation=90, ha='center', va='top')

    ax1.yaxis.set_major_formatter(mticker.PercentFormatter(1))
    ax1.grid(alpha=0.5)
    ax1.set_title(_title_text(title), fontsize=text_size + 2, weight='bold', y=1.1)

    # 先紧凑布局，再按渲染后的 bbox 自动放 legend / note
    plt.tight_layout()
    fig.canvas.draw()
    renderer = fig.canvas.get_renderer()

    ax_pos = ax1.get_position()

    # x 轴标签（若可见）最低点
    tick_bboxes = []
    for lab in ax1.get_xticklabels():
        if lab.get_visible() and lab.get_text():
            bb = lab.get_window_extent(renderer=renderer).transformed(fig.transFigure.inverted())
            tick_bboxes.append(bb)

    if tick_bboxes:
        xtick_bottom_fig = min(bb.y0 for bb in tick_bboxes)
        legend_top_fig = xtick_bottom_fig - 0.012
    else:
        # 当前函数默认隐藏 x 标签，走这个分支
        legend_top_fig = ax_pos.y0 - 0.03

    # 转到 axes 坐标
    legend_y = (legend_top_fig - ax_pos.y0) / ax_pos.height
    legend_y = max(min(legend_y, -0.02), -1.25)

    leg = ax1.legend(
        bbox_to_anchor=(0.5, legend_y),
        loc='upper center',
        ncol=legend_ncol,
        frameon=False,
        fontsize=text_size
    )

    if note != '':
        fig.canvas.draw()
        renderer = fig.canvas.get_renderer()
        leg_bb_fig = leg.get_window_extent(renderer=renderer).transformed(fig.transFigure.inverted())

        # note_x 作为“相对坐标轴左边界”的偏移，note_y 作为“相对 legend 下边界”的微调
        note_x_fig = ax_pos.x0 + 0.002 + note_x * ax_pos.width
        note_y_fig = leg_bb_fig.y0 - 0.01 + note_y

        fig.text(note_x_fig, note_y_fig, note, fontsize=11, ha='left', va='top')

    plt.savefig(f"figures/{pic_name}.png", bbox_inches='tight')

    if show_pic:
        plt.show()
    elif not encoded_pic:
        plt.close(fig)

    if encoded_pic:
        return encode_pic()


# 多条折线图：占比
# def mpl_line_mul_count(df,title,pic_name,legend_ncol,colors,note='',note_x=0.2,note_y=0,text_size=12,decimal_place=2,encoded_pic=True,show_pic=True):
#     export_plot_data(df, title, pic_name)
#     fig_legend = math.ceil(len(df.columns)/legend_ncol)
#     xlabel_h = max(s.count('\n') for s in df.index) * 0.05+1
#     fig_h = 4+xlabel_h
#     fig = plt.figure(figsize=(16, 6))
#     ax1 = fig.add_subplot(111)

#     list_te = []
#     for c,col in enumerate(df.columns):
#         ax1.plot(df.index, df[col], color=colors[c],linewidth=1,markersize=15,marker='.',label=col,)
#         for r in range(len(df.index)):
#             v_1 = df[col][r]
#             li_1 = ax1.text(r, v_1, f'{v_1:.{decimal_place}f}', ha='left', va='bottom',color=colors[c], fontsize=text_size, label=col)
#             list_te.append(li_1)
        
#         # mean_y = df[col].mean()
#         # ax1.axhline(y= mean_y, color=colors[c] ,linestyle='--')  # marker='-'
#         # y1_label = ax1.text(len(df)/(5+c), mean_y, str(col)+'均值：'+ str(round(mean_y,0)), fontsize =text_size, color=colors[c], weight='bold')
#         # list_te.append(y1_label)

#     adjust_text(list_te,force_pull=(0.01, 0.1))

#     # 不显示 xy 轴标签名字
#     ax1.set_xlabel('')
#     ax1.set_ylabel('')

#     # 调整x轴刻度标签的位置和方向
#     ax1.tick_params(axis='x', which='both', left=False, right=False, labelleft=False, labelright=False)
#     ax1.tick_params(axis='y', which='both', top=False, bottom=True, labeltop=False, labelbottom=False)
#     ax1.tick_params(axis='x', labelsize=text_size)       # 仅修改 X 轴刻度文本的字号
#     # ax1.yaxis.set_major_formatter(mticker.PercentFormatter(1))# 设置 Y 轴为百分比格式
#     ax1.tick_params(axis='y', labelsize=text_size)            # 调整刻度文本的字号

#     ax1.grid(alpha=0.5)
#     # 添加图例
#     ax1.legend(bbox_to_anchor=(0.5,-0.3*xlabel_h),loc='upper center', ncol=legend_ncol,frameon=False,fontsize=text_size)
#     ax1.set_title(title, fontsize=text_size+2,weight='bold',y=1.1)#+0.05*math.ceil(len(df.columns)/legend_ncol))

#     # 新的产生base64图片的方式
#     plt.tight_layout()
#     if note != '':
#         fig.text(x=note_x, y= note_y,s=note,fontsize=11, ha='left',va='bottom')
    
#     plt.savefig(f"figures/{pic_name}.png", bbox_inches='tight')
#     # 存为base64码并展示
#     if show_pic == True:
#         plt.show()
#     if encoded_pic == True:
#         return encode_pic()

# 多条折线图：计数
def mpl_line_mul_count(
    df, title, pic_name, legend_ncol, colors,
    note='', note_x=0.2, note_y=0,
    text_size=12, decimal_place=2,
    encoded_pic=True, show_pic=True
):
    export_plot_data(df, title, pic_name)

    df_plot = df.copy()

    # 1) x轴标签：长度>13时只换行一次；若最长>10则整体竖排
    raw_labels = [str(s) for s in df_plot.index]

    def _wrap_once(s, n=13):
        s = str(s)
        return s if len(s) <= n else s[:n] + '\n' + s[n:]

    x_labels = [_wrap_once(s, 13) for s in raw_labels]
    rotate_x = (max(len(s) for s in raw_labels) > 10) if len(raw_labels) > 0 else False

    x = np.arange(len(df_plot))

    fig = plt.figure(figsize=(12, 8))
    ax1 = fig.add_subplot(111)

    list_te = []
    for c, col in enumerate(df_plot.columns):
        y = df_plot[col].values
        ax1.plot(
            x, y,
            color=colors[c],
            linewidth=1,
            markersize=15,
            marker='.',
            label=col
        )
        for r in range(len(x)):
            v_1 = y[r]
            li_1 = ax1.text(
                x[r], v_1, f'{v_1:.{decimal_place}f}',
                ha='left', va='bottom',
                color=colors[c], fontsize=text_size
            )
            list_te.append(li_1)

    adjust_text(list_te, force_pull=(0.01, 0.1))

    # 不显示xy轴名字
    ax1.set_xlabel('')
    ax1.set_ylabel('')

    # x/y刻度显示
    ax1.set_xticks(x)
    if rotate_x:
        ax1.set_xticklabels(x_labels, rotation=90, ha='center', va='top')
    else:
        ax1.set_xticklabels(x_labels, rotation=0, ha='center')

    ax1.tick_params(axis='x', which='both', bottom=True, top=False, labelbottom=True, labeltop=False)
    ax1.tick_params(axis='y', which='both', left=True, right=False, labelleft=True, labelright=False)
    ax1.tick_params(axis='x', labelsize=text_size)
    ax1.tick_params(axis='y', labelsize=text_size)

    ax1.grid(alpha=0.5)
    ax1.set_title(_title_text(title), fontsize=text_size + 2, weight='bold', y=1.1)

    # 2) 先 tight_layout，再根据渲染后bbox自动放 legend / note
    plt.tight_layout()
    fig.canvas.draw()
    renderer = fig.canvas.get_renderer()
    ax_pos = ax1.get_position()

    # x轴标签最低点（figure坐标）
    tick_bboxes = []
    for lab in ax1.get_xticklabels():
        if lab.get_visible() and lab.get_text():
            bb = lab.get_window_extent(renderer=renderer).transformed(fig.transFigure.inverted())
            tick_bboxes.append(bb)

    if tick_bboxes:
        xtick_bottom_fig = min(bb.y0 for bb in tick_bboxes)
        legend_top_fig = xtick_bottom_fig - 0.012
    else:
        legend_top_fig = ax_pos.y0 - 0.03

    # 转为axes坐标
    legend_y = (legend_top_fig - ax_pos.y0) / ax_pos.height
    legend_y = max(min(legend_y, -0.02), -1.25)

    # legend
    handles, labels = ax1.get_legend_handles_labels()
    valid = [(h, l) for h, l in zip(handles, labels) if l and not l.startswith('_')]
    leg = None
    if valid:
        leg = ax1.legend(
            handles=[p[0] for p in valid],
            labels=[p[1] for p in valid],
            bbox_to_anchor=(0.5, legend_y),
            loc='upper center',
            ncol=max(1, min(legend_ncol, len(valid))),
            frameon=False,
            fontsize=text_size
        )

    # note
    if note != '':
        fig.canvas.draw()
        renderer = fig.canvas.get_renderer()
        if leg is not None:
            leg_bb_fig = leg.get_window_extent(renderer=renderer).transformed(fig.transFigure.inverted())
            note_y_fig = leg_bb_fig.y0 - 0.01 + note_y
        else:
            note_y_fig = ax_pos.y0 - 0.04 + note_y

        note_x_fig = ax_pos.x0 + 0.002 + note_x * ax_pos.width
        fig.text(note_x_fig, note_y_fig, note, fontsize=11, ha='left', va='top')

    plt.savefig(f"figures/{pic_name}.png", bbox_inches='tight')

    if show_pic:
        plt.show()
    elif not encoded_pic:
        plt.close(fig)

    if encoded_pic:
        return encode_pic()

# 折线图
# def mpl_line_1_count(se,colors_line,title,pic_name,data_type='',note='',note_x=0.2,note_y=0,text_size=12,mean_title='平均值',mean_title_city='本盟市平均值',show_mean=False,v_mean=0,v_mean_city=0,decimal_place=2,encoded_pic=False,show_pic=True,city_line=0):
#     export_plot_data(se, title, pic_name)
#     fig = plt.figure(figsize=(12,8),dpi=100)
#     ax1 = fig.add_subplot(111)

#     ax1.plot(
#         se.index,
#         se.values,
#         color= colors_line,
#         linewidth=1,
#         markersize=5,
#         marker='.',
#     )

#     list_te = []
#     for i in range(len(se)):
#         v_1 = se.values.tolist()[i]
#         if data_type != 'perc':
#             li_1 = ax1.text(i, v_1, f'{v_1:.{decimal_place}f}',color=colors_line, fontsize=text_size,)
#         else:
#             li_1 = ax1.text(i, v_1, f'{v_1*100:.{decimal_place}f}%',color=colors_line, fontsize=text_size,)
#         # 使用 path_effects 添加阴影效果
#         shadow = pe.withStroke(linewidth=0.2, foreground='black', alpha=0.7)  # 黑色阴影
#         li_1.set_path_effects([shadow])
#         list_te.append(li_1)

#     # 平均线
#     if show_mean ==True:
#         # ax1.axhline(y= v_mean, color='lightgray' ,linestyle='--')
#         # y1_label = ax1.text(len(se)/4, v_mean, mean_title+ str(f'{v_mean:.{decimal_place}f}'), fontsize=text_size, color='gray', weight='bold',ha='center')
#         # list_te.append(y1_label)
#         if city_line ==1:
#             ax1.axhline(y= v_mean_city, color='#cbb058' ,linestyle='--')
#             y1_label = ax1.text(len(se)/4, v_mean_city, mean_title_city+ str(f'{v_mean_city:.{decimal_place}f}'), fontsize=text_size, color='#cbb058', weight='bold',ha='center')
#             list_te.append(y1_label)

#     # 把所有需要不重叠位置的plt.text放在一个列表
#     adjust_text(list_te)

#     # 不显示 xy 轴标签名字
#     ax1.set_xlabel('')
#     ax1.set_ylabel('')

#     # 调整x轴刻度标签的位置和方向
#     ax1.tick_params(axis='x', which='both', left=False, right=False, labelleft=False, labelright=False)
#     ax1.tick_params(axis='y', which='both', top=False, bottom=True, labeltop=False, labelbottom=False)
#     ax1.tick_params(axis='x', labelsize=text_size)       # 仅修改 X 轴刻度文本的字号
#     ax1.tick_params(axis='y', labelsize=text_size)            # 调整刻度文本的字号
#     if data_type == 'perc':
#         ax1.yaxis.set_major_formatter(mticker.PercentFormatter(1))# 设置 Y 轴为百分比格式

#     ax1.grid(alpha=0.5)

#     ax1.set_title(title, fontsize=text_size+2,weight='bold')
#     # 新的产生base64图片的方式
#     plt.tight_layout()
#     # 新的产生base64图片的方式
#     plt.tight_layout()
#     if note != '':
#         fig.text(x=note_x, y= note_y,s=note,fontsize=11, ha='left',va='bottom')

#     plt.savefig(f"figures/{pic_name}.png", bbox_inches='tight')
#     # 存为base64码并展示
#     if show_pic == True:
#         plt.show()
#     if encoded_pic == True:
#         return encode_pic()

# ...existing code...
def mpl_line_1_count(
    se, colors_line, title, pic_name, data_type='',
    note='', note_x=0.2, note_y=0, text_size=12,
    mean_title='平均值', mean_title_city='本盟市平均值',
    show_mean=False, v_mean=0, v_mean_city=0,
    decimal_place=2, encoded_pic=False, show_pic=True, city_line=0
):
    export_plot_data(se, title, pic_name)
    fig = plt.figure(figsize=(12, 8), dpi=100)
    ax1 = fig.add_subplot(111)

    # x轴标签处理：>13换行一次；若最长>10则整体竖排
    raw_labels = [str(s) for s in se.index]

    def _wrap_once(s, n=13):
        return s if len(s) <= n else s[:n] + '\n' + s[n:]

    x_labels = [_wrap_once(s, 13) for s in raw_labels]
    rotate_x = (max(len(s) for s in raw_labels) > 10) if len(raw_labels) > 0 else False

    x = np.arange(len(se))
    y = se.values

    ax1.plot(
        x, y,
        color=colors_line,
        linewidth=1,
        markersize=5,
        marker='.',
        label='监测值'
    )

    list_te = []
    for i in range(len(se)):
        v_1 = y[i]
        if data_type != 'perc':
            li_1 = ax1.text(i, v_1, f'{v_1:.{decimal_place}f}', color=colors_line, fontsize=text_size)
        else:
            li_1 = ax1.text(i, v_1, f'{v_1*100:.{decimal_place}f}%', color=colors_line, fontsize=text_size)

        shadow = pe.withStroke(linewidth=0.2, foreground='black', alpha=0.7)
        li_1.set_path_effects([shadow])
        list_te.append(li_1)

    # 平均线
    if show_mean and city_line == 1:
        ax1.axhline(y=v_mean_city, color='#cbb058', linestyle='--', label=mean_title_city)
        y1_label = ax1.text(
            len(se) / 4, v_mean_city,
            mean_title_city + str(f'{v_mean_city:.{decimal_place}f}'),
            fontsize=text_size, color='#cbb058', weight='bold', ha='center'
        )
        list_te.append(y1_label)

    adjust_text(list_te)

    ax1.set_xlabel('')
    ax1.set_ylabel('')

    # x/y刻度
    ax1.set_xticks(x)
    if rotate_x:
        ax1.set_xticklabels(x_labels, rotation=90, ha='center', va='top')
    else:
        ax1.set_xticklabels(x_labels, rotation=0, ha='center')

    ax1.tick_params(axis='x', which='both', bottom=True, top=False, labelbottom=True, labeltop=False)
    ax1.tick_params(axis='y', which='both', left=True, right=False, labelleft=True, labelright=False)
    ax1.tick_params(axis='x', labelsize=text_size)
    ax1.tick_params(axis='y', labelsize=text_size)

    if data_type == 'perc':
        ax1.yaxis.set_major_formatter(mticker.PercentFormatter(1))

    ax1.grid(alpha=0.5)
    ax1.set_title(_title_text(title), fontsize=text_size + 2, weight='bold')

    # 先紧凑布局，再按渲染后的 bbox 自动放 legend / note
    plt.tight_layout()
    fig.canvas.draw()
    renderer = fig.canvas.get_renderer()
    ax_pos = ax1.get_position()

    # 计算x轴标签最低点（figure坐标）
    tick_bboxes = []
    for lab in ax1.get_xticklabels():
        if lab.get_visible() and lab.get_text():
            bb = lab.get_window_extent(renderer=renderer).transformed(fig.transFigure.inverted())
            tick_bboxes.append(bb)

    if tick_bboxes:
        xtick_bottom_fig = min(bb.y0 for bb in tick_bboxes)
        legend_top_fig = xtick_bottom_fig - 0.012
    else:
        legend_top_fig = ax_pos.y0 - 0.03

    legend_y = (legend_top_fig - ax_pos.y0) / ax_pos.height
    legend_y = max(min(legend_y, -0.02), -1.25)

    # 自动legend（有可用label才画）
    handles, labels = ax1.get_legend_handles_labels()
    valid = [(h, l) for h, l in zip(handles, labels) if l and not l.startswith('_')]
    leg = None
    if valid:
        leg = ax1.legend(
            handles=[p[0] for p in valid],
            labels=[p[1] for p in valid],
            bbox_to_anchor=(0.5, legend_y),
            loc='upper center',
            ncol=min(3, len(valid)),
            frameon=False,
            fontsize=max(9, text_size - 1)
        )

    if note != '':
        fig.canvas.draw()
        renderer = fig.canvas.get_renderer()
        if leg is not None:
            leg_bb_fig = leg.get_window_extent(renderer=renderer).transformed(fig.transFigure.inverted())
            note_y_fig = leg_bb_fig.y0 - 0.002 + note_y
        else:
            note_y_fig = ax_pos.y0 - 0.04 + note_y

        note_x_fig = ax_pos.x0 + 0.002 + note_x * ax_pos.width
        fig.text(note_x_fig, note_y_fig, note, fontsize=11, ha='left', va='top')

    plt.savefig(f"figures/{pic_name}.png", bbox_inches='tight')

    if show_pic:
        plt.show()
    elif not encoded_pic:
        plt.close(fig)

    if encoded_pic:
        return encode_pic()

    

def sns_heatmap_percent(df,colors,title,pic_name,decimal_place=0,text_size=12,cube_h=0.8,note='',note_x=0.2,note_y=0,encoded_pic=False,show_pic=True):
    export_plot_data(df, title, pic_name)
    y_max = df.replace(0,np.nan).max(skipna=True).max()
    y_min = df.replace(0,np.nan).min(skipna=True).min()

    fig = plt.figure(figsize=(14,1+cube_h*(len(df.index)+3)),dpi=100)
    ax1 = fig.add_subplot(111)
    sns.heatmap(
        df.replace(0, np.nan), 
        cmap = colors,
        annot=True, 
        annot_kws={'size': text_size, 'weight': 'bold'},
        cbar=False,
        ax=ax1,
        fmt=f'.{decimal_place}%',
        vmin=y_min, vmax=y_max,  # 需要规定vmin和vmax才能和颜色对应 
        linewidths=2, linecolor='white',  # 设置线宽为2，线的颜色为白色
    )
    # 不显示 xy 轴标签名字
    ax1.set_xlabel('')
    ax1.set_ylabel('')
    # 调整x轴刻度标签的位置和方向
    ax1.tick_params(axis='x', which='both', bottom=False, top=True, labelbottom=False, labeltop=True)
    ax1.tick_params(axis='both', which='both', length=0) # 隐藏刻度线
    yticks = ax1.get_yticklabels()
    ax1.set_yticklabels(labels= yticks, rotation= 0, fontsize=text_size)
    xticks = ax1.get_xticklabels()
    ax1.set_xticklabels(labels= xticks, rotation= 0, fontsize=text_size)

    # 标题
    # fig.suptitle(title,fontsize=text_size+2,weight='bold')
    ax1.set_title(_title_text(title), fontsize=text_size+2,weight='bold')

    # 调整colorbar对象
    divider = make_axes_locatable(ax1)                 # 使用make_axes_locatable调整颜色条的宽度
    cax = divider.append_axes("right", size="2.5%", pad=0.1)  # size调整宽度，pad调整间距
    cbar = plt.colorbar(ax1.collections[0], cax=cax)
    cbar.set_ticks([y_min, y_max])                     # 手动设置颜色条的刻度和标签
    cbar.set_ticklabels([f'{y_min:.0%}', f'{y_max:.0%}'])  # 格式化刻度标签
    cbar.outline.set_visible(False)                    # 设置颜色条边框为透明色
    plt.tight_layout()
    if note != '':
        fig.text(x=note_x, y= note_y,s=note,fontsize=11, ha='left',va='bottom')

    plt.savefig(f"figures/{pic_name}.png", bbox_inches='tight')
    # 存为base64码并展示
    if show_pic == True:
        plt.show()
    if encoded_pic == True:
        return encode_pic()
    
def mpl_line_1_perc(se,colors_line,title,pic_name,show_mean=False,v_mean=0,text_size=12,mean_title='平均值',decimal_place=0,note='',note_x=0.2,note_y=0,encoded_pic=False,show_pic=True):
    export_plot_data(se, title, pic_name)
    # se = se.fillna(0).sort_values()

    se.index = [s if len(s)==2 else '\n'.join(textwrap.wrap(s,3)) if len(s)>4 else '\n'.join(textwrap.wrap(s,2)) for s in se.index]
    fig = plt.figure(figsize=(10,4),dpi=100)
    ax1 = fig.add_subplot(111)

    ax1.plot(
        se.index,
        se.values,
        color= colors_line,
        linewidth=1,
        markersize=5,
        marker='.',
    )

    list_te = []
    for i in range(len(se)):
        v_1 = se.values.tolist()[i]
        li_1 = ax1.text(i, v_1, f'{v_1*100:.{decimal_place}f}%',color=colors_line, fontsize=text_size,)
        # 使用 path_effects 添加阴影效果
        shadow = pe.withStroke(linewidth=0.2, foreground='black', alpha=0.7)  # 黑色阴影
        li_1.set_path_effects([shadow])
        list_te.append(li_1)

    # 平均线
    if show_mean == True:
        ax1.axhline(y= v_mean, color='lightgray' ,linestyle='--')
        y1_label = ax1.text(len(se)/4, v_mean, mean_title+ str(f'{v_mean*100:.{decimal_place}f}%'), fontsize=text_size, color='gray', weight='bold',ha='center')
        list_te.append(y1_label)

    # 把所有需要不重叠位置的plt.text放在一个列表
    adjust_text(list_te)

    # 不显示 xy 轴标签名字
    ax1.set_xlabel('')
    ax1.set_ylabel('')

    # 调整x轴刻度标签的位置和方向
    ax1.tick_params(axis='x', which='both', left=False, right=False, labelleft=False, labelright=False)
    ax1.tick_params(axis='y', which='both', top=False, bottom=True, labeltop=False, labelbottom=False)
    ax1.tick_params(axis='x', labelsize=text_size)       # 仅修改 X 轴刻度文本的字号
    ax1.yaxis.set_major_formatter(mticker.PercentFormatter(1))# 设置 Y 轴为百分比格式
    ax1.tick_params(axis='y', labelsize=text_size)            # 调整刻度文本的字号

    ax1.grid(alpha=0.5)

    ax1.set_title(_title_text(title), fontsize=text_size+2,weight='bold',y=1.1)

    # 新的产生base64图片的方式
    plt.tight_layout()
    if note != '':
        fig.text(x=note_x, y= note_y,s=note,fontsize=11, ha='left',va='bottom')
    plt.savefig(f"figures/{pic_name}.png", bbox_inches='tight')
    # 存为base64码并展示
    if show_pic == True:
        plt.show()
    if encoded_pic == True:
        return encode_pic()
    

from matplotlib.ticker import FuncFormatter
# 热力图
def sns_block_heatmap_count(list_title,list_df,title,note='',note_x=0.2,note_y=0,data_type='perc',encoded_pic=True,show_pic=True,):
    """
    y_max: 最多的分层量
    """

    x_count = [df.shape[1] if df.shape[1]>0 else 1 for df in list_df]
    x_ratios = [count / sum(x_count) for count in x_count]

    # colors = colors_heatmap(1)

    fig, ax = plt.subplots(1, len(list_df),sharey='all', sharex=None, gridspec_kw={'width_ratios': x_ratios}, figsize=(12, 8))
    fig.suptitle(_title_text(title), fontsize=14, weight='bold')
    for i,df in enumerate(list_df):
        # 子图
        axi = ax[i]
        if data_type=='perc':
            colors = colors_heatmap(1)
            hm2 = sns.heatmap(
                df, # .replace(0, np.nan)
                cmap = colors,
                annot=True, 
                annot_kws={'size': 12, 'weight': 'bold'},
                cbar=False,
                ax=axi,
                fmt='.0%',
                vmin=0, vmax=1,  # 需要规定vmin和vmax才能和颜色对应 
                linewidths=2, 
                linecolor='white',  # 设置线宽为2，线的颜色为白色
            )
        elif data_type=='count':
            colors = colors_map_trans(1)
            max_v = max([df.max().max() for df in list_df])
            hm2 = sns.heatmap(
                df, # .replace(0, np.nan)
                cmap = colors,
                annot=True, 
                annot_kws={'size': 12, 'weight': 'bold'},
                cbar=False,
                ax=axi,
                fmt='.0f',
                vmin=0, vmax=max_v,  # 需要规定vmin和vmax才能和颜色对应 
                linewidths=2, 
                linecolor='white',  # 设置线宽为2，线的颜色为白色
            )
        elif data_type=='float':
            colors = colors_map_trans(1)
            max_v = max([df.max().max() for df in list_df])
            hm2 = sns.heatmap(
                df,  # .replace(0, np.nan)
                cmap = colors,
                annot=True, 
                annot_kws={'size': 12, 'weight': 'bold'},
                cbar=False,
                ax=axi,
                fmt='.2f',
                vmin=0, vmax=max_v,  # 需要规定vmin和vmax才能和颜色对应 
                linewidths=2, 
                linecolor='white',  # 设置线宽为2，线的颜色为白色
            )
        # 不显示 xy 轴标签名字
        # axi.set_xlabel('')
        axi.set_ylabel('')

        # 坐标轴标签设置
        # axi.set_xticks(x_positions, x_labels, fontsize=12)
        axi.set_xlabel(list_title[i], fontsize=14, labelpad=15, weight='bold')
        
        # # 坐标轴样式设置
        # axi.set_xlim(-0.5, len(df.index) - 0.5)# 调整x轴的范围，使柱子均匀分布
        # axi.spines['left'].set_visible(False)  # 取消框线
        # axi.spines['right'].set_visible(False)
        # axi.spines['top'].set_visible(False)
        # axi.grid(axis='y',color='lightgray',zorder=1) # 添加网格线
        axi.tick_params(axis='both', which='both', length=0) # 刻度线长度为0

    # y轴范围
    ymin, ymax = axi.get_ylim()
    ypos = (ymin + ymax) / 2  # y轴中间
    unit = 1/df.shape[0]

    # 在 y 轴外侧依次放置三个标签
    plt.text(-0.3, unit*2, "高中", va="center", ha="center", rotation=0, transform=ax[0].transAxes)
    plt.text(-0.3, unit*4+unit*2.5, "初中", va="center", ha="center", rotation=0, transform=ax[0].transAxes)
    plt.text(-0.3, unit*4+unit*5+unit*0.5, "小学", va="center", ha="center", rotation=0, transform=ax[0].transAxes)


    # 在右边单独加一个共享的 colorbar
    if data_type=='perc':
        cax = fig.add_axes([0.92, 0.1, 0.03, 0.8])  # [left, bottom, width, height]  # 指定颜色条位置和大小
        cbar = fig.colorbar(hm2.collections[0], ax=ax, location="right", shrink=0.92, cax=cax, )
        # 去掉边框
        for spine in cbar.ax.spines.values():
            spine.set_visible(False)   # 或 spine.set_edgecolor("none")
        # 设置刻度显示为百分比
        cbar.ax.yaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{x:.0%}"))
    elif data_type=='count':
        cax = fig.add_axes([0.92, 0.1, 0.03, 0.8])  # [left, bottom, width, height]  # 指定颜色条位置和大小
        cbar = fig.colorbar(hm2.collections[0], ax=ax, location="right", shrink=0.92, cax=cax, )
        # 去掉边框
        for spine in cbar.ax.spines.values():
            spine.set_visible(False)   # 或 spine.set_edgecolor("none")
        cbar.set_ticks([0, max_v])  # 设置颜色条的刻度

    # 组合图设置
    plt.subplots_adjust(wspace=0.2, right=0.9)   #, bottom=0.1, hspace=0.2, top=0.85, bottom=0.05, left= 0.12,

    if note != '':
        fig.text(x=note_x, y= note_y,s=note,fontsize=11, ha='left',va='bottom')

    # 存为base64码并展示
    if show_pic == True:
        plt.show()
    if encoded_pic == True:
        return encode_pic()
    

def plot_simple_heatmap(
    df,
    title="",
    pic_name=None,
    wrap_len=10,
    figsize=None,
    dpi=150,
    save_dir="figures",
    show_pic=True,
    note="",          # 新增：备注文本
    note_x=0.3,      # 新增：备注x位置（左侧）
    note_y=None,     # 新增：备注y位置（None=自动）
    note_fontsize=10  # 新增：备注字号
):
    """
    简单热力图：
    - 只在值为1的位置显示 √
    - 列名支持自动换行
    - 图片保存到 figures 文件夹

    参数：
    - df: DataFrame，建议值为0/1或可转成0/1
    - title: 图标题
    - pic_name: 图片名，不传则使用 title
    - wrap_len: 列名每行换行长度
    - figsize: 画布大小
    - dpi: 分辨率
    - save_dir: 保存目录
    - show_pic: 是否展示图片
    """
    df_plot = df.copy().fillna(0)
    export_plot_data(df_plot, title, pic_name)

    # 只在1的位置显示√
    annot_text = np.where(df_plot.values == 1, "√", "")

    # 列名换行
    df_plot.columns = [
        "\n".join(textwrap.wrap(str(c), width=wrap_len)) if len(str(c)) > wrap_len else str(c)
        for c in df_plot.columns
    ]

    # 图片名
    if not pic_name:
        pic_name = title if title else "simple_check_heatmap"
    pic_name = re.sub(r'[\\/:*?"<>|]', "_", str(pic_name))

    os.makedirs(save_dir, exist_ok=True)

    n_rows = max(int(df_plot.shape[0]), 1)
    n_cols = max(int(df_plot.shape[1]), 1)
    cells = n_rows * n_cols

    if cells <= 24:
        annot_fontsize = 11
        linewidths = 0.8
    elif cells <= 120:
        annot_fontsize = 10
        linewidths = 0.6
    else:
        annot_fontsize = 9
        linewidths = 0.5

    if n_rows <= 10:
        ytick_fontsize = 11
    elif n_rows <= 20:
        ytick_fontsize = 10
    else:
        ytick_fontsize = 9

    if figsize is None:
        # Default behavior: fixed width, dynamic height by content size.
        w = 12.0
        cell_h = 0.44 if n_rows <= 12 else 0.36
        raw_h = 1.9 + cell_h * n_rows + (0.45 if note else 0.0)
        h = float(np.clip(raw_h, 3.6, 11.5))
        figsize_use = (w, h)
    else:
        figsize_use = figsize

    fig, ax = plt.subplots(figsize=figsize_use, dpi=dpi)
    sns.heatmap(
        df_plot,
        cmap=sns.color_palette(["#f2f2f2", "#A1D0C7"]),
        vmin=0, vmax=1,
        cbar=False,
        linewidths=linewidths,
        linecolor="white",
        annot=annot_text,
        fmt="",
        annot_kws={"fontsize": annot_fontsize, "fontweight": "bold", "color": "black"},
        ax=ax
    )

    ax.set_xlabel("")
    ax.set_ylabel("")
    ax.set_title(_title_text(title), fontsize=14, fontweight="bold", pad=12)
    ax.tick_params(axis="x", which="both", top=True, bottom=False, labeltop=True, labelbottom=False)
    ax.tick_params(axis="both", which="both", length=0)
    ax.set_yticklabels(
        ax.get_yticklabels(),
        rotation=0,
        va="center",
        fontsize=ytick_fontsize,
    )  # 防止y轴文字垂直旋转

    note_prefix = "\u5907\u6ce8\uff1a"
    if note:
        if note_y is None:
            # 先紧凑布局，再按渲染后的 bbox 自动放置备注
            plt.tight_layout()
            fig.canvas.draw()
            renderer = fig.canvas.get_renderer()
            ax_bbox = ax.get_position()

            ytick_bboxes = []
            for tick in ax.get_yticklabels():
                if tick.get_text():
                    ytick_bboxes.append(
                        tick.get_window_extent(renderer=renderer).transformed(fig.transFigure.inverted())
                    )

            left_bound = min([ax_bbox.x0] + [bb.x0 for bb in ytick_bboxes]) if ytick_bboxes else ax_bbox.x0
            note_x_auto = max(0.01, left_bound)
            note_y_auto = max(0.01, ax_bbox.y0 - 0.012)

            note_artist = fig.text(
                note_x_auto,
                note_y_auto,
                note_prefix + str(note),
                ha="left",
                va="top",
                fontsize=note_fontsize,
            )

            fig.canvas.draw()
            renderer = fig.canvas.get_renderer()
            note_bbox = note_artist.get_window_extent(renderer=renderer).transformed(fig.transFigure.inverted())

            # 兜底1：避免触底裁切
            if note_bbox.y0 < 0.005:
                x0, y0 = note_artist.get_position()
                note_artist.set_position((x0, y0 + (0.005 - note_bbox.y0)))
                fig.canvas.draw()
                renderer = fig.canvas.get_renderer()
                note_bbox = note_artist.get_window_extent(renderer=renderer).transformed(fig.transFigure.inverted())

            # 兜底2：如果与绘图区发生重叠，重新留底部空白并重定位
            if note_bbox.y1 >= (ax_bbox.y0 - 0.002):
                reserve = min(0.18, max(0.06, note_bbox.height + 0.02))
                plt.tight_layout(rect=[0, reserve, 1, 1])
                fig.canvas.draw()
                renderer = fig.canvas.get_renderer()
                ax_bbox = ax.get_position()

                ytick_bboxes = []
                for tick in ax.get_yticklabels():
                    if tick.get_text():
                        ytick_bboxes.append(
                            tick.get_window_extent(renderer=renderer).transformed(fig.transFigure.inverted())
                        )
                left_bound = min([ax_bbox.x0] + [bb.x0 for bb in ytick_bboxes]) if ytick_bboxes else ax_bbox.x0
                note_x_auto = max(0.01, left_bound)
                note_y_auto = max(0.01, ax_bbox.y0 - 0.008)
                note_artist.set_position((note_x_auto, note_y_auto))

                fig.canvas.draw()
                renderer = fig.canvas.get_renderer()
                note_bbox = note_artist.get_window_extent(renderer=renderer).transformed(fig.transFigure.inverted())
                if note_bbox.y0 < 0.005:
                    x0, y0 = note_artist.get_position()
                    note_artist.set_position((x0, y0 + (0.005 - note_bbox.y0)))
        else:
            fig.text(note_x, note_y, note_prefix + str(note), ha="left", va="bottom", fontsize=note_fontsize)
            plt.tight_layout(rect=[0, 0.05, 1, 1])  # 给底部备注留空间
    else:
        plt.tight_layout()

    save_path = os.path.join(save_dir, f"{pic_name}.png")
    plt.savefig(save_path, bbox_inches="tight")

    if show_pic:
        plt.show()
    else:
        plt.close(fig)
    
# 生师比箱图
def boxplot_sub_area(df_ori,list_df,col,list_index,tit,str_chartname_item,pic_name,note_x=0.13,note_y=-0.15,show_pic=True,encoded_pic=False):
    export_plot_data(df_ori, tit, pic_name)
    
    # 学科维度
    fig = plt.figure(figsize=(16,5))
    fig.suptitle(_title_text(tit), fontsize=14, weight='bold')
    ax1 = fig.add_subplot(111)

    box1 = ax1.boxplot(list_df, patch_artist=True, widths=0.4, showfliers=False)

    # 坐标轴标签设置
    ax1.set_xticks(list(range(1,1+len(list_index))), list_index, fontsize=12)
    ax1.tick_params(axis='x', labelsize=14)                   # 调整刻度文本的字号
    ax1.tick_params(axis='both', which='both', length=0)
    ax1.grid(axis='both')

    for i,sub in enumerate(list_index):
        df = list_df[i]
        x_position = np.random.normal(i+1, 0.06, size=len(df))  # 生成带有水平抖动的x坐标
        ax1.scatter(x_position, df, edgecolor='gray', facecolor='gray', s=5, alpha=0.3, zorder=2)   # 控制图层 

    # 备注
    dishu_counts_text = df_ori.drop_duplicates(subset=['school',col]).groupby(col)['school'].count().reindex(list_index)
    sample_words = '\n'.join(textwrap.wrap(para_series(dishu_counts_text.dropna().astype(int), str_unit='学校')+str_chartname_item+'。',75))
    note = f'备注：\n样本量（各学科填写该题的学校数量）：\n{sample_words}\n'

    if note != '':
        fig.text(x=note_x, y= note_y,s=note,fontsize=11, ha='left',va='bottom')

    plt.savefig(f"figures/{pic_name}.png", bbox_inches='tight')
    # 存为base64码并展示
    if show_pic == True:
        plt.show()
    if encoded_pic == True:
        return encode_pic()

# 根据df算出一列最大的value长度(含列名):
def list_col_length(df):
    # 各列的宽度
    list_col_width = []
    for col in df.columns:
        # 列值的长度
        list_v = []
        for s in df[col]:
            if str(s).find('\n')==-1:
                list_v.append(len(str(s)))
            else:
                list_n = s.split('\n')
                list_v.append(max([len(str(sp)) for sp in list_n]))
        v = max(list_v)
        # 列名的长度
        if str(col).find('\n')==-1:
            c = len(col)
        else:
            list_n = col.split('\n')
            c = max([len(str(sp)) for sp in list_n])

        col_width = max(c, v)
        list_col_width.append(col_width)

    return list_col_width


# 根据给定的df的index和columns产生表格图片：
def table_col_index(df, w_t=0.2,h_d=0.6, tit='', note='',note_x=0.2,note_y=0,encoded_pic=False,show_pic=True,):

    # 各列的宽度
    list_col_width = [w*w_t for w in list_col_length(df)]
    # 各列的宽度比
    x_ratios = [w / sum(list_col_width) for w in list_col_width]
    fig, ax = plt.subplots(figsize=(0.9*sum(list_col_width), h_d*df.shape[0]))
    ax.axis('tight')
    # 把轴关掉用
    ax.axis('off')
    # # 选项列的宽度

    table = ax.table(cellText=df.values, colLabels=df.columns, rowLabels=None,colLoc='center' ,rowLoc='center', bbox=[0, 0, 1, 1], cellLoc='center',colWidths=x_ratios ,colColours=['lightgray']*df.shape[1])
    table.auto_set_font_size(False)
    table.set_fontsize(12)
    if _title_text(tit):
        fig.suptitle(_title_text(tit),fontsize=14,weight='bold')
    plt.tight_layout()
    if note != '':
        if df.shape[0] == 1:
            fig.text(x=note_x, y= note_y-0.5,s=note,fontsize=11, ha='left',va='bottom')
        else:
            fig.text(x=note_x, y= note_y,s=note,fontsize=11, ha='left',va='bottom')

    # 存为base64码并展示
    if show_pic == True:
        plt.show()
    if encoded_pic == True:
        return encode_pic()
    

def plot_simple_check_heatmap(
    df,
    title="",
    pic_name=None,
    wrap_len=10,
    figsize=(12, 8),
    dpi=150,
    save_dir="figures",
    show_pic=True
):
    """
    简单热力图：
    - 只在值为1的位置显示 √
    - 列名支持自动换行
    - 图片保存到 figures 文件夹

    参数：
    - df: DataFrame，建议值为0/1或可转成0/1
    - title: 图标题
    - pic_name: 图片名，不传则使用 title
    - wrap_len: 列名每行换行长度
    - figsize: 画布大小
    - dpi: 分辨率
    - save_dir: 保存目录
    - show_pic: 是否展示图片
    """
    df_plot = df.copy().fillna(0)

    # 只在1的位置显示√
    annot_text = np.where(df_plot.values == 1, "√", "")

    # 列名换行
    df_plot.columns = [
        "\n".join(textwrap.wrap(str(c), width=wrap_len)) if len(str(c)) > wrap_len else str(c)
        for c in df_plot.columns
    ]

    # 图片名
    if not pic_name:
        pic_name = title if title else "simple_check_heatmap"
    pic_name = re.sub(r'[\\/:*?"<>|]', "_", str(pic_name))

    os.makedirs(save_dir, exist_ok=True)

    plt.figure(figsize=figsize, dpi=dpi)
    ax = sns.heatmap(
        df_plot,
        cmap=sns.color_palette(["#f2f2f2", "#A1D0C7"]),
        vmin=0, vmax=1,
        cbar=False,
        linewidths=1,
        linecolor="white",
        annot=annot_text,
        fmt="",
        annot_kws={"fontsize": 12, "fontweight": "bold", "color": "black"}
    )

    ax.set_xlabel("")
    ax.set_ylabel("")
    ax.set_title(_title_text(title), fontsize=14, fontweight="bold", pad=12)

    # x轴刻度放到上方
    ax.tick_params(
        axis="x",
        which="both",
        top=True,
        bottom=False,
        labeltop=True,
        labelbottom=False
    )
    ax.tick_params(axis="both", which="both", length=0)

    plt.tight_layout()
    save_path = os.path.join(save_dir, f"{pic_name}.png")
    plt.savefig(save_path, bbox_inches="tight")

    if show_pic:
        plt.show()
    else:
        plt.close()


# ── 以下内容来自 analysis_functions.py ──────────────────────────────
import pandas as pd
import math

# 执行上下文变量（由 notebook 调用 set_context() 注入）
level_key = None
level_name = None
g_by = None
g_by_name = None
list_lower_level = None

def set_context(lk, ln, gb, gbn, lll):
    """同步 notebook 执行上下文到本模块的全局变量"""
    global level_key, level_name, g_by, g_by_name, list_lower_level
    level_key, level_name, g_by, g_by_name, list_lower_level = lk, ln, gb, gbn, lll


# 统计函数
def basic_count(df_ori,col,list_alt,source_name):
    """
        使用基础数据表做基础统计
    """
    df = df_ori[col].value_counts().reindex(list_alt).to_frame()
    df['perc'] = df['count'].div(df['count'].sum())
    df = df.fillna(0)
    df.loc['总计'] = df.sum(axis=0)
    df['perc'] = df['perc'].apply(lambda x: f'{x*100:.0f}%')
    t_df = f'备注：样本量N={df_ori.shape[0]}，数据来源{source_name}。'
    return df, t_df


# 常规单选题的统计
def alt_count_area(df, list_alt, tit, pic_name,note_add, note_y=-0.1,special=0):

    colors=colors_choice(len(list_alt))[::-1]
    # 预处理
    df['alternative'] = df['alternative'].replace(r'其他，.*|其它，.*','其他',regex=True)

    # 全自治区
    df_1 = df.groupby('alternative')['school'].count().rename('自治区').to_frame()
    # 本盟市
    if level_key == 'city':
        df_city = df[(df['city']==level_name)]
        df_1[level_name] = df_city.groupby('alternative')['school'].count()
        sample_counts = df_city['school'].nunique() # 样本总量
    else:
        sample_counts = df['school'].nunique()
    # 次级行政单位
    df_city['school_1'] = df_city['school'].copy()
    df_1[list_lower_level] = pd.pivot_table(
        df_city,
        index='alternative',
        columns=g_by,
        values='school_1',
        aggfunc='count',
    ).reindex(columns=list_lower_level, index=list_alt)
    # display(df_1.reindex(index=list_alt))
    df_1 = df_1.div(df_1.sum(axis=0),axis=1).reindex(index=list_alt[::-1]).T.fillna(0)
    if level_key =='city':
        df_1 = df_1.drop(index='自治区')

    # 备注
    note_df_1 = f'备注：\n{level_name}数据样本量N={sample_counts}，' + note_add
    # display(df_1,note_df_1)

    df_1.index = [s if len(s)<4 else '\n'.join(textwrap.wrap(s,3)) if len(s)>4 else '\n'.join(textwrap.wrap(s,2)) for s in df_1.index]
    max_newlines = max(s.count('\n') for s in df_1.index)
    if max_newlines>4:
        add_note_y = (max_newlines - 4)*0.05
    else:
        add_note_y=0
    mpl_stack_bar_mul_perc(df=df_1, title=tit, pic_name=pic_name, colors=colors,wrap_l=12, legend_ncol=df_1.shape[1],note=note_df_1,note_y=note_y-add_note_y,note_x=0.12,show_pic=True,special=special)

# 单选题/多选题中某个选项的占比
def aim_alt_perc_area(df,list_alt,aim_alt,tit,pic_name,col=None,list_col=None,alt_col='alternative',str_chartname_item='',note_x=0.2,note_y=0,):
    col = col or g_by
    list_col = list_col or list_lower_level
    # 文字描述的去重
    if str_chartname_item.find('学校')!=-1:
        list_dup_text = ['school']
        list_dup_dishu = list_dup_text
    elif str_chartname_item.find('教研组')!=-1:
        list_dup_text = ['school',col]
        if col != 'subject':
            list_dup_dishu = list_dup_text + ['subject',]
        else:
            list_dup_dishu = list_dup_text
    elif str_chartname_item.find('教师')!=-1:
        list_dup_text = ['school',col,'user_id']
        if col != 'subject':
            list_dup_dishu = list_dup_text + ['subject','user_id']
        else:
            list_dup_dishu = list_dup_text
    elif str_chartname_item.find('学生')!=-1:
        list_dup_text = ['school',col,'grade','user_id']
        if col != 'subject':
            list_dup_dishu = list_dup_text + ['subject','grade','user_id']
        else:
            list_dup_dishu = list_dup_text

    # 底数
    # -- 自治区
    sample_counts = df.drop_duplicates(subset=list_dup_dishu).shape[0] # 样本总量
    # -- 本区
    if level_key == 'city':
        sample_counts_city = df.loc[df['city']==level_name,'school'].shape[0] # 样本总量
    # -- 各次级维度
    dishu_counts = df.drop_duplicates(subset=list_dup_dishu).groupby(col)['school'].count().reindex(list_col)

    # 全自治区
    df_1 = df.groupby(alt_col)['school'].count().div(sample_counts).rename('自治区').to_frame()
    # 本区
    if level_key == 'city':
        df_city = df[(df['city']==level_name)]
        df_1[level_name] = df_city.groupby(alt_col)['school'].count().div(sample_counts_city)
    # 次级行政单位
    df_city['school_1'] = df_city['school'].copy()
    df_1[list_col] = pd.pivot_table(
        df_city,
        index=alt_col,
        columns=col,
        values='school_1',
        aggfunc='count',
    ).reindex(columns=list_col, index=list_alt)
    display(dishu_counts, df_1[list_col].reindex(index=list_alt))

    # 转百分比
    df_1[list_col] = df_1[list_col].div(dishu_counts, axis=1)
    if level_key == 'city':
        df_1 = df_1.drop(columns='自治区')

    # 备注
    if str_chartname_item.find('学校')!=-1:
        note = f'备注：\n{level_name}数据样本量N={sample_counts}，' + str_chartname_item + '。'
        if level_key=='city':
            note = f'备注：\n{level_name}数据样本量N={sample_counts_city}，' + str_chartname_item + '。'
    else:
        dishu_counts_text = df.drop_duplicates(subset=list_dup_text).groupby(col)['item_no'].count().reindex(list_col)
        sample_words = '\n'.join(textwrap.wrap(para_series(dishu_counts_text.dropna().astype(int), str_unit='学校')+str_chartname_item+'。',75))
        note = f'备注：\n样本量（各学科填写该题的学校数量）：\n{sample_words}\n'

    df_1 = df_1.reindex(index=list_alt[::-1]).T.fillna(0)
    mpl_line_1_perc(
        se=df_1[aim_alt],
        colors_line=colors_choice(1)[0],
        title=tit,
        pic_name=pic_name,
        note=note,
        note_x=note_x,
        note_y=note_y,
    )

def table_count_perc_df(df, col_count='', col_perc='', decimal_place=0,col='alternative',list_opt=[]):

    df = df.drop(df[df[col].isna()].index)
    if len(list_opt) == 0:
        df_1 = df[col].value_counts().reset_index().rename(columns={col:'选项','count':'数量'}).sort_values(by='数量',ascending=False)
    else:
        df_1 = df[col].value_counts().reindex(list_opt).fillna(0).reset_index().rename(columns={col:'选项','count':'数量'})
    sample_counts = df['school'].nunique() # 样本总量
    df_1['数量'] = df_1['数量'].astype(int)
    df_1['占比'] = df_1['数量'].div(sample_counts).apply(lambda x: f'{x*100:.{decimal_place}f}%')

    if col_count=='' and col_perc=='':
        df = df_1
    else:
        df = df_1.rename(columns={'数量':col_count,'占比':col_perc,})
    display(df)
    return df

# 单选题和多选题的选项统计表格
def table_count_perc(df, col_count='', col_perc='',tit='', decimal_place=0,col='alternative',list_opt=[],note='',note_x=0.2,note_y=0,encoded_pic=False,show_pic=True,):

    df = df.drop(df[df[col].isna()].index)
    if len(list_opt) == 0:
        df_1 = df[col].value_counts().reset_index().rename(columns={col:'选项','count':'数量'}).sort_values(by='数量',ascending=False)
    else:
        df_1 = df[col].value_counts().reindex(list_opt).fillna(0).reset_index().rename(columns={col:'选项','count':'数量'})
    sample_counts = df['school'].nunique() # 样本总量
    df_1['数量'] = df_1['数量'].astype(int)
    df_1['占比'] = df_1['数量'].div(sample_counts).apply(lambda x: f'{x*100:.{decimal_place}f}%')

    if col_count=='' and col_perc=='':
        df = df_1
    else:
        df = df_1.rename(columns={'数量':col_count,'占比':col_perc,})
    display(df)
    return df

# 针对数值项求g_by的均值和整体的均值，输出折线图
def col_count_mean(df, col, tit,pic_name,ind=None,ind_name='自治区',ind_name_city=None,list_index=None, note_source='',note_x=0.02,note_y=0,city_line=0):
    ind = ind or g_by
    ind_name_city = ind_name_city or level_name
    list_index = list_index or list_lower_level

    df[col] = df[col].astype(float)

    # 第一张图
    v_mean = df[col].mean()
    v_mean_city = df[df['city']==level_name][col].mean()
    se_1 = df.groupby(ind)[col].mean().reindex(list_index)

    # 备注
    sample_counts = df['school'].nunique()
    if level_key == 'city':
        sample_counts = df[df['city']==level_name]['school'].nunique()
    note = f'备注：样本量N={sample_counts}，数据来源{note_source}。'

    mpl_line_1_count(se=se_1,colors_line=colors_choice(2)[0],title=tit,pic_name=pic_name,note=note,note_x=note_x,note_y=note_y,mean_title=ind_name+'平均值',mean_title_city=ind_name_city+'平均值',show_mean=True,v_mean=v_mean,v_mean_city=v_mean_city ,show_pic=True,city_line=city_line)

# 教材政治方向分学科组合图
def text_subplots(df,tit,pic_name,str_chartname_item,list_alt=['同意', '不同意'],show_pic=True, encoded_pic=False):

    dishu_counts = df.groupby('subject')['school'].count().reindex(list_sub_tb)
    df['alternative'] = df['alternative'].replace(r'不同意，.*','不同意',regex=True)

    # 1、合并教材基础信息
    df_1 = pd.merge(df,df_basic_tb, on=['subject','school'],how='left')

    # 2、各学校的作答情况
    df_2 = pd.pivot_table(
        df_1,
        index=['subject','textbook'],
        columns='alternative',
        values='school',
        aggfunc='count',
    ).reindex(index=multi_col_tb, columns=list_alt)
    df_2['不同意'] = df_2['不同意'].fillna(0)
    df_2['同意'] = df_2['同意'].fillna(0)
    df_2 = df_2.div(df_2.sum(axis=1),axis=0).reset_index().rename(columns={'alternative':'textbook'})

    export_plot_data(df_2, tit, pic_name)
    fig, ax = plt.subplots(4,3,sharey=True,sharex='none', figsize=(16, 10))

    for i in range(len(list_sub_tb)):

        sub = list_sub_tb[i]
        ax1 = ax[int(i/3), i-3*int(i/3)]
        se_0 = df_2.loc[df_2['subject']==sub, ['textbook','同意']].set_index('textbook')
        se_1 = se_0['同意'].reindex(dict_sub_tb[sub]).dropna()
        se_1.index = [s if len(se_1)==1 else '\n'.join(textwrap.wrap(s,math.ceil(28/len(se_1))))  for s in se_1.index]
        bars_1 = ax1.plot(se_1.index, se_1.values,linewidth=1,markersize=30,marker='.',)
        # 只有一个点时，补一条同色水平线
        if len(se_1) == 1:
            y0 = float(se_1.iloc[0])
            ax1.axhline(y=y0, linewidth=1, alpha=0.9)

        for j, ind in enumerate(se_1.index.tolist()):
            v_1 = se_1[ind]
            ax1.text(j, v_1*0.75, f'{v_1*100:.0f}%', ha='center', va='center', fontsize=12, weight='bold')
        ax1.set_title(_title_text(sub),fontsize=12)
        ax1.tick_params(axis='x', which='both', left=False, right=False, labelleft=False, labelright=False)
        ax1.tick_params(axis='y', which='both', top=False, bottom=True, labeltop=False, labelbottom=False)
        ax1.tick_params(axis='x', labelsize=12)
        ax1.yaxis.set_major_formatter(mticker.PercentFormatter(1))
        ax1.tick_params(axis='y', labelsize=12)
        ax1.set_ylim( -0.05, 1.2)

    fig.delaxes(ax[3, 2])

    fig.subplots_adjust(top=0.6, bottom=0.15, left= 0.05, right=0.95, wspace=0, hspace=0.22)
    fig.suptitle(_title_text(tit),fontsize=14,weight='bold',y=1)
    plt.tight_layout()

    # 备注
    sample_words = '\n'.join(textwrap.wrap(para_series(dishu_counts.dropna().astype(int), str_unit='学校')+f'数据来源于{str_chartname_item}。',110))
    note = f'备注：\n样本量（各学科填写该题的学校数量）：\n{sample_words}\n'
    fig.text(x=0.04, y= -0.06,s=note,fontsize=11, ha='left',va='bottom')

    plt.savefig(f"figures/{pic_name}.png", dpi=300, bbox_inches='tight')
    if show_pic == True :
        plt.show()
    if encoded_pic == True:
        return encode_pic()


# 计算不同的field_name的平均值
def mul_x_mean_line(df, list_fn, replace_str,str_chartname_item,tit,pic_name,level_name,col=None,list_col=None,note_x=0,note_y=0):
    col = col or g_by
    list_col = list_col or list_lower_level

    # 全自治区
    df_1 = df.groupby('field_name')['field_value'].mean().rename('自治区').to_frame()
    # 本盟市
    if level_key == 'city':
        df_city = df[(df['city']==level_name)]
        df_1[level_name] = df_city.groupby('field_name')['field_value'].mean()
        sample_counts = df_city['school'].nunique() # 样本总量
    else:
        sample_counts = df['school'].nunique()
    # 次级行政单位
    df_1[list_col] = pd.pivot_table(
        df,
        index='field_name',
        columns=col,
        values='field_value',
        aggfunc='mean',
    ).reindex(columns=list_col, index=list_fn)

    df_1.index = [ind.replace(replace_str,'平均值') for ind in df_1.index]
    df_1 = df_1.T
    display(df_1)
    if level_key == 'city':
        df_1 = df_1.drop(index='自治区')

    # 备注
    note_df_1 = f'备注：\n{level_name}数据样本量N={sample_counts}，{str_chartname_item}。'

    mpl_line_mul_count(df=df_1,decimal_place=2, note=note_df_1, colors=colors_choice(df_1.shape[1]), title=tit,legend_ncol=df_1.shape[1],pic_name = pic_name, note_x=note_x, note_y=note_y)

# 学科和选项的热力图。一个学科有多个学校
def alt_x_heatmap_count_perc(df,ind,list_index,list_alt,tit,str_chartname_item,pic_name,note_add='',decimal_place=0,note_x=0.05,note_y=-0.15):

    # 文字描述的去重
    if str_chartname_item.find('学校')!=-1:
        list_dup_text = ['school']
        list_dup_dishu = list_dup_text
    elif str_chartname_item.find('教研组')!=-1:
        list_dup_text = ['school',ind]
        if ind != 'subject':
            list_dup_dishu = list_dup_text + ['subject',]
        else:
            list_dup_dishu = list_dup_text
    elif str_chartname_item.find('教师')!=-1:
        list_dup_text = ['school',ind,'user_id']
        if ind != 'subject':
            list_dup_dishu = list_dup_text + ['subject','user_id']
        else:
            list_dup_dishu = list_dup_text
    elif str_chartname_item.find('学生')!=-1:
        list_dup_text = ['school',ind,'grade','user_id']
        if ind != 'subject':
            list_dup_dishu = list_dup_text + ['subject','grade','user_id']
        else:
            list_dup_dishu = list_dup_text

    df_1 = pd.pivot_table(
        df,
        index=ind,
        columns='alternative',
        values='item_no',
        aggfunc='count',
    ).reindex(list_index, columns=list_alt)

    dishu_counts_dishu = df.drop_duplicates(subset=list_dup_dishu).groupby(ind)['item_no'].count().reindex(list_index)
    df_1 = df_1.div(dishu_counts_dishu, axis=0)

    # 备注
    dishu_counts_text = df.drop_duplicates(subset=list_dup_text).groupby(ind)['item_no'].count().reindex(list_index)
    sample_words = '\n'.join(textwrap.wrap(para_series(dishu_counts_text.dropna().astype(int), str_unit='学校')+str_chartname_item+'。',90))
    if ind=='school':
        sample_words = f"{df['school'].nunique()}所,{str_chartname_item}。"
        note = f'备注：\n样本量（各学科填写该题的学校数量）：{sample_words}\n'+note_add
    else:
        note = f'备注：\n样本量（各学科填写该题的学校数量）：\n{sample_words}\n'+note_add

    df_1.columns = ['\n'.join(textwrap.wrap(col,6))  for col in df_1.columns]
    sns_heatmap_percent(df=df_1,decimal_place=decimal_place,title = tit,colors=colors_map_trans(1), cube_h=0.3, pic_name=pic_name,note= note, note_x=note_x,note_y=note_y)

# 计算 学科×col维度，某个选项的占比
def sub_perc_aim_alt(df, aim_alt, aim_col,list_col,tit,note,pic_name,wrap_len=6):
    # list_col如果为空 则获得df的school列 首字母排序,逆序
    if not list_col:
        list_col = sorted(df['school'].unique(), reverse=True)
    if aim_col == 'city':
        new_name ='本盟市'
    else:
        new_name = '自治区'
    # 全自治区
    df_1_dishu = df.groupby('subject')['school'].count().rename(new_name).to_frame()
    # 次级行政单位
    df_1_dishu[list_col] = pd.pivot_table(
        df,
        index='subject',
        columns=aim_col,
        values='school',
        aggfunc='count',
    ).reindex(columns=list_col,index=list_sub[:9])

    # 全自治区
    df_1 = df[df['alternative']==aim_alt].groupby('subject')['school'].count().rename(new_name).to_frame()

    # 次级行政单位
    df_1[list_col] = pd.pivot_table(
        df[df['alternative']==aim_alt],
        index='subject',
        columns=aim_col,
        values='school',
        aggfunc='count',
    ).reindex(columns=list_col,index=list_sub[:9])
    df_1 = df_1.div(df_1_dishu).reindex(index=list_sub[:9])

    # 备注
    df_1.columns = ['\n'.join(textwrap.wrap(col,wrap_len))  for col in df_1.columns]
    sns_heatmap_percent(df=df_1, colors=colors_map_trans(1), cube_h=0.3, title=tit,note= note, note_x=0.05,note_y=-0.15,pic_name=pic_name)

def mpl_stack_bar_mul_perc_school(
    df, title, pic_name, colors, legend_ncol,
    note='', note_x=0, note_y_shift=0,
    w=0.72, text_size=12, decimal_place=0, wrap_l=13,
    wrap_once_len=13, encoded_pic=False, show_pic=True, special=0,line_space=0.5
):
    """
    学校为X轴的堆叠百分比条形图（专用）
    - 学校名换行一次（不是截断）
    - 固定竖排X轴
    - legend / note 自动偏移
    """
    export_plot_data(df, title, pic_name)
    df_plot = df.copy()

    # 学校名：只换行一次
    def _wrap_once(s, n=13):
        s = str(s)
        return s if len(s) <= n else s[:n] + '\n' + s[n:]

    x_labels = [_wrap_once(s, wrap_once_len) for s in df_plot.index]
    x = np.arange(len(df_plot.index))
    n_school = len(x)

    # 画布：稍微加长
    fig_h = 6.6 + max(0, n_school - 12) * 0.10
    fig = plt.figure(figsize=(18, fig_h))
    ax1 = fig.add_subplot(111)

    bo_m = np.zeros(n_school)
    valid_cols = []
    for c, col in enumerate(df_plot.columns):
        col_values = df_plot[col].fillna(0).values
        if col_values.sum() > 0:
            valid_cols.append(col)
            ax1.bar(x, col_values, width=w, bottom=bo_m, color=colors[c], label=col)

            for r in range(n_school):
                v_1 = col_values[r]
                if special == 0:
                    if v_1 > 0:
                        ax1.text(
                            x[r], bo_m[r] + v_1 / 2,
                            f'{v_1*100:.{decimal_place}f}%',
                            ha='center', va='center',
                            fontsize=text_size-1, weight='bold'
                        )
                else:
                    if v_1 > 0 and (len(str(df_plot.index[r])) < 5):
                        ax1.text(
                            x[r], bo_m[r] + v_1 / 2,
                            f'{v_1*100:.{decimal_place}f}%',
                            ha='center', va='center',
                            fontsize=text_size-1, weight='bold'
                        )
            bo_m = bo_m + col_values

    ax1.set_xticks(x)
    ax1.set_xticklabels(x_labels, rotation=90, ha='center')
    for label in ax1.get_xticklabels():
        label.set_linespacing(line_space)
    ax1.tick_params(axis='x', labelsize=max(8, text_size-1), length=0)
    ax1.tick_params(axis='y', labelsize=text_size)
    ax1.yaxis.set_major_formatter(mticker.PercentFormatter(1))
    ax1.set_xlim(-0.5, n_school - 0.5)
    ax1.set_ylim(-0.05, 1.05)

    legend_handles = []
    for c, col in enumerate(df_plot.columns):
        wrapped_text = '\n'.join(textwrap.wrap(str(col), width=wrap_l))
        legend_handles.append(Patch(color=colors[c], label=wrapped_text))

    legend_ncol_adj = min(legend_ncol, 5)
    legend_rows = max(1, math.ceil(max(1, len(valid_cols)) / legend_ncol_adj))

    fig.canvas.draw()
    renderer = fig.canvas.get_renderer()

    tick_bboxes = []
    for lab in ax1.get_xticklabels():
        if lab.get_text():
            bb = lab.get_window_extent(renderer=renderer).transformed(fig.transFigure.inverted())
            tick_bboxes.append(bb)

    ax_pos = ax1.get_position()
    if tick_bboxes:
        xtick_bottom_fig = min(bb.y0 for bb in tick_bboxes)
        legend_top_fig = xtick_bottom_fig - 0.012
    else:
        legend_top_fig = ax_pos.y0 - 0.03

    legend_y = (legend_top_fig - ax_pos.y0) / ax_pos.height
    legend_y = max(min(legend_y, -0.02), -1.25)

    ax1.legend(
        handles=legend_handles[::-1],
        bbox_to_anchor=(0.5, legend_y),
        loc='upper center',
        ncol=legend_ncol_adj,
        frameon=False,
        fontsize=max(8, text_size-2)
    )

    ax1.set_title(_title_text(title), fontsize=text_size+2, weight='bold', y=1.04)

    leg = ax1.legend(
        handles=legend_handles[::-1],
        bbox_to_anchor=(0.5, legend_y),
        loc='upper center',
        ncol=legend_ncol_adj,
        frameon=False,
        fontsize=max(8, text_size-2)
    )

    ax1.set_title(_title_text(title), fontsize=text_size+2, weight='bold', y=1.04)

    if note != '':
        fig.canvas.draw()
        renderer = fig.canvas.get_renderer()
        leg_bb_fig = leg.get_window_extent(renderer=renderer).transformed(fig.transFigure.inverted())
        ax_pos = ax1.get_position()

        note_x_fig = ax_pos.x0 + 0.002 + note_x * ax_pos.width
        note_y_fig = leg_bb_fig.y0 - 0.01 + note_y_shift

        fig.text(
            note_x_fig, note_y_fig, note,
            fontsize=11, ha='left', va='top'
        )

    plt.savefig(f"figures/{pic_name}.png", bbox_inches='tight', dpi=300)

    if show_pic:
        plt.show()
    if encoded_pic:
        return encode_pic()

# # 计算 学科×col维度，某个选项的占比
def alt_x_bar_count_perc(df,col,list_col,list_alt,str_chartname_item,tit,pic_name,note_x=0.12,note_y=-0.15,wrap_l=12,school=0,city_name='本盟市'):

    colors = colors_choice(len(list_alt))[::-1]
    df_1 = df.groupby('alternative')['school'].count().rename('自治区').to_frame()
    if city_name:
        df_1 = df.groupby('alternative')['school'].count().rename(city_name).to_frame()
    # 次级行政单位
    df_1[list_col] = pd.pivot_table(
        df,
        index='alternative',
        columns=col,
        values='school',
        aggfunc='count',
    ).reindex(columns=list_col,index=list_alt).fillna(0)
    df_1 = df_1.div(df_1.sum(axis=0),axis=1).reindex(index=list_alt).T
    df_1 = df_1.fillna(0)
    max_newlines = max(s.count('\n') for s in df_1.index)
    if max_newlines>2:
        add_note_y = (max_newlines-2)*0.05
    else:
        add_note_y=0
    # 备注
    dishu_counts = df.drop_duplicates(subset=[col,'school']).groupby(col)['school'].count().reindex(list_col)

    if 'school' in col:
        note = (f"备注：\n样本量（本盟市填写该题的学校数量）：{df['school'].nunique()}所,"
                f"数据来源于{str_chartname_item}。")
    else:
        sample_words = '\n'.join(
            textwrap.wrap(
                para_series(dishu_counts.dropna().astype(int),
                            str_unit='学校')
                + f'数据来源于{str_chartname_item}。', 90
            )
        )
        note = (
            f'备注：\n样本量（各学科填写该题的学校数量）：\n'
            f'{sample_words}\n'
        )
    if school == 1:
        mpl_stack_bar_mul_perc_school(df=df_1, title=tit, pic_name=pic_name, colors=colors,wrap_l=wrap_l, legend_ncol=df_1.shape[1],note=note,show_pic=True,line_space=1)
    else:
        mpl_stack_bar_mul_perc(df=df_1, title=tit, pic_name=pic_name, colors=colors,wrap_l=wrap_l, legend_ncol=df_1.shape[1],note=note,note_y=note_y-add_note_y,note_x=note_x,show_pic=True,)

# 计算几类作业分年级占比的均值
def grade_mean_subplots(df,col,var_name,list_col,str_chartname_item,show_pic=True,encoded_pic=True,note_x=0.02,note_y=-0.05):
    list_grade = ['高一年级','高二年级','高三年级',]
    results = []
    pic_tits = []
    for i,item in enumerate(['作业类型比例_基础','作业类型比例_拓展','作业类型比例_实践',]):

        tit_name = re.sub('比例_','中',item) + '类内容'
        tit='各'+var_name+tit_name+'占比分布'

        colors = colors_choice(3)[i]

        df_2 = df[df['field_name'].str.contains(item,na=False)].copy()
        df_3 = pd.pivot_table(
            df_2,
            index=col,
            columns='grade',
            values='field_value',
            aggfunc='mean',
        ).reindex(index=list_col,columns=list_grade)

        fig, ax = plt.subplots(1,3,sharey=True,sharex=True, figsize=(16, 5))
        for j in range(3):
            grade = list_grade[j]
            ax1 = ax[j]
            se_1 = df_3[grade].reindex(list_col)

            bars_1 = ax1.bar(se_1.index, se_1.values, width=0.7, color=colors,)
            if len(se_1.index)>13:
                text_size=8
            else:
                text_size=12
            for ind, v_1 in se_1.items():
                if v_1>0:
                    ax1.text(ind, v_1*0.75,  f'{v_1*100:.0f}%', ha='center', va='center', fontsize=text_size)
            ax1.set_title(_title_text(grade),fontsize=12)
            if var_name != '荣誉类型学校':
                ax1.tick_params(axis='x', labelsize=10, rotation=90)
            else:
                ax1.tick_params(axis='x', labelsize=10)
            ax1.tick_params(axis='both',length=0)
            ax1.tick_params(axis='x', labelsize=12)
            ax1.yaxis.set_major_formatter(mticker.PercentFormatter(1))

        fig.subplots_adjust(top=0.6, bottom=0.15, left= 0.05, right=0.95, wspace=0, hspace=0.22)
        fig.suptitle(_title_text(tit),fontsize=14,weight='bold',)
        plt.tight_layout()

        note = f'1.数据来源于{str_chartname_item}。\n2.计算方法：先以年级为维度，将各学校内各学科教研组填写数值转化为比例；再以年级和{var_name}为统计单位计算平均值。'
        if note != '':
            fig.text(x=note_x, y= note_y,s=note,fontsize=11, ha='left',va='bottom')

        results.append(fig)
        pic_tits.append(tit)
        export_plot_data(df=df_3,title=tit,pic_name="miss")
        if show_pic == True:
            plt.show()
    return results,pic_tits


# 计算分年级数量的均值
def grade_mean_subplots_sub_count(df,col,var_name,list_col,str_chartname_item,pic_name,show_pic=True,encoded_pic=True,decimal_place=1,note_x=0.12,note_y=-0.05):

    list_grade = ['高一年级','高二年级','高三年级',]
    tit='各'+var_name+tit_name+'均值'

    df_3 = pd.pivot_table(
        df,
        index=col,
        columns='grade',
        values='field_value',
        aggfunc='mean',
    ).reindex(index=list_col,columns=list_grade)
    fig, ax = plt.subplots(1,3,sharey=True,sharex=True, figsize=(16, 5))
    for i in range(3):
        colors = colors_choice(3)[i]
        grade = list_grade[i]
        ax1 = ax[i]
        se_1 = df_3[grade].reindex(list_col)

        bars_1 = ax1.bar(se_1.index, se_1.values, width=0.7, color=colors,)
        for ind, v_1 in se_1.items():
            if v_1>0:
                ax1.text(ind, v_1*0.75,  f'{v_1:.{decimal_place}f}', ha='center', va='center', fontsize=12, weight='bold')
        ax1.set_title(_title_text(grade),fontsize=12)
        ax1.tick_params(axis='x', labelsize=10, rotation=90)
        ax1.tick_params(axis='both',length=0)
        ax1.tick_params(axis='x', labelsize=12)

    fig.subplots_adjust(top=0.6, bottom=0.15, left= 0.05, right=0.95, wspace=0, hspace=0.22)
    fig.suptitle(_title_text(tit),fontsize=14,weight='bold',)
    plt.tight_layout()

    note = f'1.数据来源于{str_chartname_item}。\n2.计算方法：先以年级为维度，计算各学校学生人数大于0的科目组合数量；再以年级和{var_name}为统计单位计算平均值。'
    if note != '':
        fig.text(x=note_x, y= note_y,s=note,fontsize=11, ha='left',va='bottom')
    export_plot_data(df_3, tit, pic_name)
    plt.savefig(f'./figures/{pic_name}.png', dpi=300, bbox_inches='tight')
    if show_pic == True:
        plt.show()
