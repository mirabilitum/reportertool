rm(list = ls())
setwd("/Users/sonyal/Library/Mobile Documents/com~apple~CloudDocs/狗生4 - SRT/16 青岛3学段")
########################################################
# 包+函数+数据读入
########################################################
source("2 code/0_functions.R")
library(openxlsx)
library(dplyr)
library(writexl)

########################################################
# 学生数据读入
########################################################
# index数据
index_h <- read.xlsx("3 index/1 【高中】青岛项目问卷题目信息表20260324.xlsx", sheet = "high_item", startRow = 2)%>%
    mutate(题目列名 = gsub("\\s+", "", 题目列名))


# 先读取列名，确定要读取的列数（排除最后3列）
all_cols <- read.xlsx("5 high_original_dataset/2025年高中学生问卷4758.xlsx", rows = 1)
n_cols_to_read <- ncol(all_cols) - 3

dat_stu_h_ori <- read.xlsx("5 high_original_dataset/2025年高中学生问卷4758.xlsx", cols = 1:n_cols_to_read) %>%
    # 清理列名中的特殊字符（包括 U+00A0 不换行空格）
    rename_with(~ gsub("\u00A0", " ", .)) %>%
    rename_with(~ gsub("\\s+", " ", .)) %>%
    rename_with(~ trimws(.))
# dat_stu_h_basic_infor <- read.xlsx("5 high_original_dataset/高中学生问卷账号.xlsx")
# table(dat_stu_h_ori$`79.本学期以来，你每周多长时间参加校外学科类课外辅导(含辅导班、家教等)？（单选题）`) / nrow(dat_stu_h_ori)

#### 家长数据读入
# dat_par_h_basic_infor <- read.xlsx("5 high_original_dataset/高中家长问卷账号.xlsx") %>%
#     ## 需要通过【用户名】与dat_par_h 的【用户账号】列匹配
#     select(用户账号 = 用户名, 区市, 学校) %>%
#     # 清理列名中的特殊字符
#     rename_with(~ gsub("\u00A0", " ", .)) %>%
#     rename_with(~ gsub("\\s+", " ", .)) %>%
#     rename_with(~ trimws(.))

dat_par_h_ori <- read.xlsx("5 high_original_dataset/2025年高中家长问卷4515.xlsx") %>%
    # 清理列名中的特殊字符
    rename_with(~ gsub("\u00A0", " ", .)) %>%
    rename_with(~ gsub("\\s+", " ", .)) %>%
    rename_with(~ trimws(.)) %>%
    mutate(账号 = gsub("jz", "", 账号))

#### 教师数据读入
# dat_tea_h_basic_infor <- read.xlsx("5 high_original_dataset/高中教师问卷账号.xlsx") %>%
#     select(用户账号 = 用户名, 区市, 学校 = 学校名称) %>%
#     # 清理列名中的特殊字符
#     rename_with(~ gsub("\u00A0", " ", .)) %>%
#     rename_with(~ gsub("\\s+", " ", .)) %>%
#     rename_with(~ trimws(.))

dat_tea_h_ori <- read.xlsx("5 high_original_dataset/2025年高中教师问卷3640.xlsx") %>%
    # 清理列名中的特殊字符
    rename_with(~ gsub("\u00A0", " ", .)) %>%
    rename_with(~ gsub("\\s+", " ", .)) %>%
    rename_with(~ trimws(.)) 
    
# colnames(dat_par_h_ori)[ncol(dat_par_h_ori)-10:ncol(dat_par_h_ori)]










########################################################
# dat_stu_h_ori 学生数据清洗
########################################################

### 家长问卷和学生问卷合并
dat_stu_h <- dat_stu_h_ori %>%
    full_join(dat_par_h_ori, by = c("账号" = "账号", "区市"), suffix = c("_学生", "_家长")) %>%
    # 清理XML乱码字符
    mutate(across(where(is.character), ~ gsub('xml:space="preserve">', '', .x, fixed = TRUE))) %>%
    mutate(across(where(is.character), ~ gsub('xml:space="preserve"', '', .x, fixed = TRUE))) %>%
    mutate(across(where(is.character), ~ trimws(.x))) %>%
    rename_all(~ gsub("\\s+", "", .x))

# 数量统计
# 学生原始数据
nrow(dat_stu_h_ori)
# 家长原始数据
nrow(dat_par_h_ori)
# 合并后的数据
nrow(dat_stu_h)


### 1、基础信息处理
# 区市 的顺序是：局属学校、西海岸新区、城阳区、即墨区、胶州市、平度市、莱西市
# Gen：性别levels = c("男", "女")
# Loc：城乡【家长问卷】levels = c("乡村", "镇驻地", "城区")
# Fam：家庭结构l evels = c("完整家庭", "父母离婚", "父亲或母亲去世")
# Sim：子女数量 （需要处理家庭成员结构也是这个变量）levels = c("独生子女", "1个", "2个及以上")
# Edu_m：母亲学历【家长问卷】levels = c("高中及以下", "大学", "研究生")
# Edu_f：父亲学历【家长问卷】levels = c("高中及以下", "大学", "研究生")
# SES：家庭教育投入【家长问卷】levels = c("较低", "较高")
dat_stu_h <- dat_stu_h %>%
    mutate(
        区市 = factor(区市, levels = c("局属学校", "西海岸新区", "城阳区", "即墨区", "胶州市", "平度市", "莱西市")),
        Gen = factor(`1.你的性别是：（单选题）`, levels = c("男", "女")),
        Loc = factor(ifelse(`7.孩子现居住地位于：（单选题）` %in% c("乡村", "镇驻地", "城区"), 
                             `7.孩子现居住地位于：（单选题）`, 
                             NA), 
                     levels = c("乡村", "镇驻地", "城区")),
        Fam = factor(`4.你的家庭情况是：（单选题）`, levels = c("完整家庭", "父母离婚", "父亲或母亲去世")),
        Sim = factor(case_when(
            `2.你家中有几个亲兄弟姐妹(除你之外)？（单选题）` == "0个(你是独生子女)" ~ "独生子女",
            `2.你家中有几个亲兄弟姐妹(除你之外)？（单选题）` == "1个" ~ "二孩",
            `2.你家中有几个亲兄弟姐妹(除你之外)？（单选题）` %in% c("2个", "3个或3个以上") ~ "多孩",
            TRUE ~ NA_character_
        ), levels = c("独生子女", "二孩", "多孩")),
        Edu_m = factor(case_when(
            `3.孩子妈妈的学历是：（单选题）` == "不清楚" ~ NA_character_,
            `3.孩子妈妈的学历是：（单选题）` %in% c("没有上过学", "小学", "初中") ~ "初中及以下",
            `3.孩子妈妈的学历是：（单选题）` %in% c("高中（含职业高中、中专）") ~ "高中",
            `3.孩子妈妈的学历是：（单选题）` %in% c("大专") ~ "大专",
            `3.孩子妈妈的学历是：（单选题）` %in% c("大学本科", "研究生（硕士或博士）") ~ "大学本科及以上",
            TRUE ~ NA_character_
        ), levels = c("初中及以下", "高中", "大专", "大学本科及以上")),
        Edu_f = factor(case_when(
            `2.孩子爸爸的学历是：（单选题）` == "不清楚" ~ NA_character_,
            `2.孩子爸爸的学历是：（单选题）` %in% c("没有上过学", "小学", "初中") ~ "初中及以下",
            `2.孩子爸爸的学历是：（单选题）` %in% c("高中（含职业高中、中专）") ~ "高中",
            `2.孩子爸爸的学历是：（单选题）` %in% c("大专") ~ "大专",
            `2.孩子爸爸的学历是：（单选题）` %in% c("大学本科", "研究生（硕士或博士）") ~ "大学本科及以上",
            TRUE ~ NA_character_
        ), levels = c("初中及以下", "高中", "大专", "大学本科及以上")),

        SES = factor(case_when(
            `11.今年，您在孩子教育方面的支出大约是：（单选题）` %in% c("500元及以下", "501~1000元", "1001~3000元", "3001~5000元", "5001~7000元", "7001~10000元") ~ "较低",
            `11.今年，您在孩子教育方面的支出大约是：（单选题）` %in% c("10001~15000元", "15001~20000元", "20001~50000元", "50000元以上") ~ "较高",
            TRUE ~ NA_character_
        ), levels = c("较低", "较高"))
    ) 
# 检查列名中是否还有U+00A0特殊字符
# grep("\u00A0", colnames(dat_stu_h), value = TRUE)

### 2、所有的量表题目，转为分数；
dat_stu_h <- dat_stu_h %>%
    mutate(across(contains("量表题"), ~ gsub("^([0-9]+)\\(.*$", "\\1", .))) %>%
    # 将所有量表题转换为数值型
    mutate(across(contains("量表题"), ~ as.numeric(.))) %>%
    # 83.本学期，你的学习压力感受如何？（单选题） 当作量表题处理
    mutate(`83.本学期，你的学习压力感受如何？（单选题）` = case_when(
        `83.本学期，你的学习压力感受如何？（单选题）` == "压力很大" ~ 1,
        `83.本学期，你的学习压力感受如何？（单选题）` == "压力比较大" ~ 2,
        `83.本学期，你的学习压力感受如何？（单选题）` == "压力适中" ~ 3,
        `83.本学期，你的学习压力感受如何？（单选题）` == "压力比较小" ~ 4,
        `83.本学期，你的学习压力感受如何？（单选题）` == "压力很小" ~ 5,
        TRUE ~ NA_real_
    )) %>%

    # 88.请选择最符合你的真实情况的选项。（量表题） 第一个选项是【未选考】，需要去掉
    # 首先备份原始数据（列名加上"_处理前"后缀）
    mutate(across(contains("88.请选择最符合你的真实情况的选项。（量表题）"), 
                  .fns = list(处理前 = ~ .),
                  .names = "{.col}_处理前")) %>%
    # 然后对原始列进行recode处理（排除已备份的列）
    mutate(across(c(
        contains("88.请选择最符合你的真实情况的选项。（量表题）") & !contains("_处理前")
    ), 
    ~ case_when(
        as.numeric(.) == 1 ~ NA_real_,
        as.numeric(.) == 2 ~ 1,
        as.numeric(.) == 3 ~ 2,
        as.numeric(.) == 4 ~ 3,
        as.numeric(.) == 5 ~ 4,
        as.numeric(.) == 6 ~ 5,
        TRUE ~ as.numeric(.)
    ))) %>%


### 3、一些特殊变量与特殊题目

    # 15.下列描述中，请根据你家的真实情况作出选择。（量表题）--3.你的父亲和母亲的关系如何？ [关系非常好 关系较好 关系一般及以下（一般+不太好+很不好）]
    mutate(父母关系 = case_when(
        `15.下列描述中，请根据你家的真实情况作出选择。（量表题）--3.你的父亲和母亲的关系如何？` == 1 ~ "关系非常好",
        `15.下列描述中，请根据你家的真实情况作出选择。（量表题）--3.你的父亲和母亲的关系如何？` == 2 ~ "关系较好",
        `15.下列描述中，请根据你家的真实情况作出选择。（量表题）--3.你的父亲和母亲的关系如何？` %in% c(3, 4, 5) ~ "关系一般及以下",
        TRUE ~ NA_character_
    )) %>%

    # 16.请选择最符合你实际情况的选项（量表题）--2.父母经常鼓励我 [符合+不符合]
    mutate(父母鼓励行为 = case_when(
        `16.请选择最符合你实际情况的选项（量表题）--2.父母经常鼓励我` %in% c(1, 2) ~ "不符合",
        `16.请选择最符合你实际情况的选项（量表题）--2.父母经常鼓励我` %in% c(3, 4) ~ "符合",
        TRUE ~ NA_character_
    )) %>%

    # 23.本学期，你每天在校体育运动的时间是?（单选题）【合并选项，"1.5小时及以上" 】
    mutate(`23.本学期，你每天在校体育运动的时间是?（单选题）` = case_when(
        `23.本学期，你每天在校体育运动的时间是?（单选题）` %in% c("1.5～2小时(不含2小时)", "2小时及以上") ~ "1.5小时及以上",
        TRUE ~ `23.本学期，你每天在校体育运动的时间是?（单选题）`
    )) %>%

    # 12.今年，您在孩子学科课外辅导的支出大约是：（单选题）[需要合并选项为0.5万元以下、0.5-1万元、1万元以上、没有参加课外辅导]
    mutate(`12.今年，您在孩子学科课外辅导的支出大约是：（单选题）_合并` = case_when(
        `12.今年，您在孩子学科课外辅导的支出大约是：（单选题）` %in% c("500元及以下","501~1000元", "1001~3000元", "3001~5000元") ~ "0.5万元以下",
        `12.今年，您在孩子学科课外辅导的支出大约是：（单选题）` %in% c("5001~7000元","7001~10000元") ~ "0.5-1万元",
        `12.今年，您在孩子学科课外辅导的支出大约是：（单选题）` %in% c("10001~15000元", "15001~20000元", "20001~50000元", "50000元以上") ~ "1万元以上",
        TRUE ~ `12.今年，您在孩子学科课外辅导的支出大约是：（单选题）`
    )) %>%

    # 13.您家里大概有多少本书（不包括报刊、杂志、学生课本及教辅）？（单选题）[需要合并选项—— 20本以下 ，21-50本，51-100本，101本以上]
    mutate(`13.您家里大概有多少本书（不包括报刊、杂志、学生课本及教辅）？（单选题）`= case_when(
        `13.您家里大概有多少本书（不包括报刊、杂志、学生课本及教辅）？（单选题）` %in% c("0~20本") ~ "20本以下",
        `13.您家里大概有多少本书（不包括报刊、杂志、学生课本及教辅）？（单选题）` %in% c("101~200本", "200本以上") ~ "101本以上",
        TRUE ~ `13.您家里大概有多少本书（不包括报刊、杂志、学生课本及教辅）？（单选题）`
    )) %>%

    # 113.（多选题）本学期，你在家里做过哪些家务？（多选题） [需要特殊处理，数个数；其他 算一个]
    mutate(家务类型数量 = sapply(`113.（多选题）本学期，你在家里做过哪些家务？（多选题）`, function(x) {
        if (is.na(x)) return(NA_integer_)
        # 用"|\r\n"分割
        items <- strsplit(x, "\\|\\r\\n", fixed = FALSE)[[1]]
        # 排除"以上都没做过"
        items <- items[items != "以上都没做过"]
        # 检查是否包含"其他"
        has_other <- any(grepl("其他", items))
        # 排除所有包含"其他"的项
        items <- items[!grepl("其他", items)]
        # 如果原来有"其他"相关的项，加1
        count <- length(items) + ifelse(has_other, 1, 0)
        return(count)
    })) %>%

    # 家务类型数量：0-2类，3-4类，5类及以上
    mutate(家务类型数量_Class = factor(case_when(
        家务类型数量 >= 0 & 家务类型数量 <= 2 ~ "0-2类",
        家务类型数量 >= 3 & 家务类型数量 <= 4 ~ "3-4类",
        家务类型数量 >= 5 ~ "5类及以上",
        TRUE ~ NA_character_
    ), levels = c("0-2类", "3-4类", "5类及以上"))) %>%

    # 115.（多选题）本学期，你在学校参加过哪些劳动？（多选题） [需要特殊处理，数个数；其他 算一个]
    mutate(校园劳动数量 = sapply(`115.（多选题）本学期，你在学校参加过哪些劳动？（多选题）`, function(x) {
        if (is.na(x)) return(NA_integer_)
        # 用"|\r\n"分割
        items <- strsplit(x, "\\|\\r\\n", fixed = FALSE)[[1]]
        # 排除"以上都没做过"
        items <- items[items != "以上都没做过"]
        # 检查是否包含"其他"
        has_other <- any(grepl("其他", items))
        # 排除所有包含"其他"的项
        items <- items[!grepl("其他", items)]
        # 如果原来有"其他"相关的项，加1
        count <- length(items) + ifelse(has_other, 1, 0)
        return(count)
    })) %>%

    # 校园劳动数量：0-2类，3-4类，5类及以上
    mutate(校园劳动_Class = factor(case_when(
        校园劳动数量 >= 0 & 校园劳动数量 <= 2 ~ "0-2类",
        校园劳动数量 >= 3 & 校园劳动数量 <= 4 ~ "3-4类",
        校园劳动数量 >= 5 ~ "5类及以上",
        TRUE ~ NA_character_
    ), levels = c("0-2类", "3-4类", "5类及以上"))) %>%

    # 21题单选题，选择了非常充足、比较充足的选项删掉22题的数据
    mutate(`22.（多选题）导致你的睡眠时间少的主要原因有哪些?（多选题）` = 
        ifelse(`21.本学期，你的睡眠时间充足吗?（单选题）` %in% c("非常充足", "比较充足"), 
               NA_character_, 
               `22.（多选题）导致你的睡眠时间少的主要原因有哪些?（多选题）`)) %>%
    # 78题，选择没有参加的，79、80、81、82题删除
    mutate(`79.本学期以来，你每周多长时间参加校外学科类课外辅导(含辅导班、家教等)？（单选题）` = 
        ifelse(`78.本学期，你参加与考试科目相关的校外补习(含家教、补习班、辅导班)情况是？（单选题）` %in% c("没有参加", "没有"), 
               "本学期没有参加", 
               `79.本学期以来，你每周多长时间参加校外学科类课外辅导(含辅导班、家教等)？（单选题）`)) %>%
    mutate(`80.（多选题）本学期，你每周都参加的、与考试相关的校外补习科目有哪些？（多选题）` = 
        ifelse(`78.本学期，你参加与考试科目相关的校外补习(含家教、补习班、辅导班)情况是？（单选题）` %in% c("没有参加", "没有"), 
               NA_character_, 
               `80.（多选题）本学期，你每周都参加的、与考试相关的校外补习科目有哪些？（多选题）`)) %>%
    mutate(`81.（多选题）本学期，你参加校外补习(含家教、补习班、辅导班)原因有哪些？（多选题）` = 
        ifelse(`78.本学期，你参加与考试科目相关的校外补习(含家教、补习班、辅导班)情况是？（单选题）` %in% c("没有参加", "没有"), 
               NA_character_, 
               `81.（多选题）本学期，你参加校外补习(含家教、补习班、辅导班)原因有哪些？（多选题）`)) %>%
    mutate(`82.（多选题）本学期，你参加过什么类型的补习？（多选题）` = 
        ifelse(`78.本学期，你参加与考试科目相关的校外补习(含家教、补习班、辅导班)情况是？（单选题）` %in% c("没有参加", "没有"), 
               NA_character_, 
               `82.（多选题）本学期，你参加过什么类型的补习？（多选题）`))%>%
    mutate(
        学习空间 = case_when(
            `14.您家中是否有以下物品：（量表题）--5.有孩子安静学习的空间` == 1 ~ "没有",
            `14.您家中是否有以下物品：（量表题）--5.有孩子安静学习的空间` == 2 ~ "有",
            TRUE ~ NA_character_
        ),
        个人电脑 = case_when(
            `14.您家中是否有以下物品：（量表题）--4.供孩子学习和做作业的个人电脑（或学习机、平板）` == 1 ~ "没有",
            `14.您家中是否有以下物品：（量表题）--4.供孩子学习和做作业的个人电脑（或学习机、平板）` == 2 ~ "有",
            TRUE ~ NA_character_
        )
        
    ) %>%
    mutate(`30.您认为孩子在学习方面存在的主要问题是（单选题）` = 
        ifelse(grepl("其他", `30.您认为孩子在学习方面存在的主要问题是（单选题）`, fixed = TRUE), 
               "其他", 
               `30.您认为孩子在学习方面存在的主要问题是（单选题）`)
    )
    
dat_stu_h <- dat_stu_h  %>%
    mutate(
        # 亲子关系感知
        亲子关系感知 = factor(case_when(
            `16.请选择最符合你实际情况的选项（量表题）--4.我对自己和父母的关系感到满意` == 1 ~ "很不符合",
            `16.请选择最符合你实际情况的选项（量表题）--4.我对自己和父母的关系感到满意` == 2 ~ "不太符合",
            `16.请选择最符合你实际情况的选项（量表题）--4.我对自己和父母的关系感到满意` == 3 ~ "比较符合",
            `16.请选择最符合你实际情况的选项（量表题）--4.我对自己和父母的关系感到满意` == 4 ~ "很符合",
            TRUE ~ NA_character_
        ), levels = c("很不符合", "不太符合", "比较符合", "很符合")),
        
        # 父母共处感受
        父母共处感受 = factor(case_when(
            `16.请选择最符合你实际情况的选项（量表题）--5.我喜欢和父母待在一起` == 1 ~ "很不符合",
            `16.请选择最符合你实际情况的选项（量表题）--5.我喜欢和父母待在一起` == 2 ~ "不太符合",
            `16.请选择最符合你实际情况的选项（量表题）--5.我喜欢和父母待在一起` == 3 ~ "比较符合",
            `16.请选择最符合你实际情况的选项（量表题）--5.我喜欢和父母待在一起` == 4 ~ "很符合",
            TRUE ~ NA_character_
        ), levels = c("很不符合", "不太符合", "比较符合", "很符合")),
        
        # 父母理解情况
        父母理解情况 = factor(case_when(
            `16.请选择最符合你实际情况的选项（量表题）--1.父母能理解我的想法` == 1 ~ "很不符合",
            `16.请选择最符合你实际情况的选项（量表题）--1.父母能理解我的想法` == 2 ~ "不太符合",
            `16.请选择最符合你实际情况的选项（量表题）--1.父母能理解我的想法` == 3 ~ "比较符合",
            `16.请选择最符合你实际情况的选项（量表题）--1.父母能理解我的想法` == 4 ~ "很符合",
            TRUE ~ NA_character_
        ), levels = c("很不符合", "不太符合", "比较符合", "很符合"))
    ) %>%
    rename("105.请你想一想：你们班符合下面描述的同学大约有多少？（量表题）--3.生活朴素节俭" = "105.请你想一想：你们班符合下面描述的同学大约有多少？（量表题）-3.生活朴素节俭")


dat_stu_h <- dat_stu_h  %>%
    mutate(
        # 学校总体满意度：基于"57.请根据您的感受，在每道题后做出选择。（量表题）--1.您对孩子所在学校的办学质量感到"
        学校总体满意度_Class = factor(case_when(
            `57.请根据您的感受，在每道题后做出选择。（量表题）--1.您对孩子所在学校的办学质量感到` == 1 ~ "不满意",
            `57.请根据您的感受，在每道题后做出选择。（量表题）--1.您对孩子所在学校的办学质量感到` == 2 ~ "不太满意",
            `57.请根据您的感受，在每道题后做出选择。（量表题）--1.您对孩子所在学校的办学质量感到` == 3 ~ "基本满意",
            `57.请根据您的感受，在每道题后做出选择。（量表题）--1.您对孩子所在学校的办学质量感到` == 4 ~ "比较满意",
            `57.请根据您的感受，在每道题后做出选择。（量表题）--1.您对孩子所在学校的办学质量感到` == 5 ~ "满意",
            TRUE ~ NA_character_
        ), levels = c("不满意", "不太满意", "基本满意", "比较满意", "满意")),
        
        # 青岛市总体满意度：基于"57.请根据您的感受，在每道题后做出选择。（量表题）--2.您对青岛市教育发展感到"
        青岛市总体满意度_Class = factor(case_when(
            `57.请根据您的感受，在每道题后做出选择。（量表题）--2.您对青岛市教育发展感到` == 1 ~ "不满意",
            `57.请根据您的感受，在每道题后做出选择。（量表题）--2.您对青岛市教育发展感到` == 2 ~ "不太满意",
            `57.请根据您的感受，在每道题后做出选择。（量表题）--2.您对青岛市教育发展感到` == 3 ~ "基本满意",
            `57.请根据您的感受，在每道题后做出选择。（量表题）--2.您对青岛市教育发展感到` == 4 ~ "比较满意",
            `57.请根据您的感受，在每道题后做出选择。（量表题）--2.您对青岛市教育发展感到` == 5 ~ "满意",
            TRUE ~ NA_character_
        ), levels = c("不满意", "不太满意", "基本满意", "比较满意", "满意")),
        
        # 区市总体满意度：基于"57.请根据您的感受，在每道题后做出选择。（量表题）--3.您对居住地的区（市）教育发展，感到"
        区市总体满意度_Class = factor(case_when(
            `57.请根据您的感受，在每道题后做出选择。（量表题）--3.您对居住地的区（市）教育发展，感到` == 1 ~ "不满意",
            `57.请根据您的感受，在每道题后做出选择。（量表题）--3.您对居住地的区（市）教育发展，感到` == 2 ~ "不太满意",
            `57.请根据您的感受，在每道题后做出选择。（量表题）--3.您对居住地的区（市）教育发展，感到` == 3 ~ "基本满意",
            `57.请根据您的感受，在每道题后做出选择。（量表题）--3.您对居住地的区（市）教育发展，感到` == 4 ~ "比较满意",
            `57.请根据您的感受，在每道题后做出选择。（量表题）--3.您对居住地的区（市）教育发展，感到` == 5 ~ "满意",
            TRUE ~ NA_character_
        ), levels = c("不满意", "不太满意", "基本满意", "比较满意", "满意"))
    )

# 筛选数据：学生问卷和家长问卷（供后续使用）
index_h_filtered <- index_h[which(index_h$数据表名 %in% c("学生问卷", "家长问卷")),]
# 筛选有子维度的数据
index_h_subdim <- index_h[which(index_h$数据表名 %in% c("学生问卷", "家长问卷") & !is.na(index_h$子维度)),]

# 3、多选题处理
dat_stu_h <- MultiChoice_to_Numeric(dat_stu_h, index_h_filtered)

# 4、反向题处理：
# 筛选出需要反向的题目
reverse_items <- index_h %>%
    filter(!is.na(是否反向) & 是否反向 == "R" & 数据表名 %in% c("学生问卷", "家长问卷")) %>%
    pull(题目列名)

# 对每个反向题进行处理
for (col_name in reverse_items) {
    # 检查列是否存在
    if (col_name %in% colnames(dat_stu_h)) {
        # 先复制原列到新列（反向前）
        backup_col_name <- paste0(col_name, "_反向前")
        dat_stu_h[[backup_col_name]] <- dat_stu_h[[col_name]]
        
        # 将列转换为数值型
        dat_stu_h[[col_name]] <- as.numeric(dat_stu_h[[col_name]])
        
        # 找到最大值（排除NA）
        max_val <- max(dat_stu_h[[col_name]], na.rm = TRUE)
        
        # 反向处理：用(最大值+1)减去原值
        dat_stu_h[[col_name]] <- (max_val + 1) - dat_stu_h[[col_name]]
    } else {
        # 如果找不到该列，打印题目列名但不影响循环
        cat("警告：在dat_stu_h中找不到列：", col_name, "\n")
    }
}

dat_stu_h <- dat_stu_h %>%
    # 焦虑和抑郁：包含特定字符串的列，所有值减去1（这个也要在反向后处理）
    # 首先备份原始数据（列名加上"_处理前"后缀）
    mutate(across(contains("54.下面是人们常有的一些感受。在最近一周，你大约几天有过以下感受？"), 
                  .fns = list(处理前 = ~ .),
                  .names = "{.col}_处理前")) %>%
    mutate(across(contains("55.在最近两周里，你是否经常有下列感受？选择最符合你出现这种感受的选项。"), 
                  .fns = list(处理前 = ~ .),
                  .names = "{.col}_处理前")) %>%
    # 然后对原始列进行减1处理（排除已备份的列）
    { 
        # 获取所有匹配的原始列名（不包含"_处理前"）
        all_cols <- colnames(.)
        target_cols_54 <- all_cols[grepl("54\\.下面是人们常有的一些感受。在最近一周，你大约几天有过以下感受？", all_cols) & 
                                    !grepl("_处理前$", all_cols)]
        target_cols_55 <- all_cols[grepl("55\\.在最近两周里，你是否经常有下列感受？选择最符合你出现这种感受的选项。", all_cols) & 
                                    !grepl("_处理前$", all_cols)]
        target_cols <- c(target_cols_54, target_cols_55)
        # 对每个原始列进行减1处理
        result <- .
        for (col_name in target_cols) {
            result <- result %>%
                mutate(!!sym(col_name) := as.numeric(!!sym(col_name)) - 1)
        }
        result
    } 




# 5、计算维度分数和分类

# 5.1 计算均分（MEAN）
dat_stu_h <- Cal_MEAN(dat_stu_h, index_h_filtered)

# 5.2 计算总分（SUM）
dat_stu_h <- Cal_SUM(dat_stu_h, index_h_filtered)

# 5.3 根据选项分类（ClassChoice）
dat_stu_h <- Cal_ClassChoice(dat_stu_h, index_h_filtered)

# 5.4 按阈值分类（ClassThreshold）
# 获取需要ClassThreshold的维度列表
threshold_dims <- index_h_filtered %>%
    filter(!is.na(算法) & grepl("ClassThreshold", 算法)) %>%
    pull(报告维度) %>%
    unique() %>%
    .[!is.na(.)]
if (length(threshold_dims) > 0) {
    dat_stu_h <- Cal_ClassThreshold(dat_stu_h, index_h_filtered, dim_list = threshold_dims)
}

# 5.5 根据类别计算指标（FigureClass）
dat_stu_h <- Cal_FigureClass(dat_stu_h, index_h_filtered)

# 5.6 计算占比（FigureRate）
# 获取需要FigureRate的维度列表
rate_dims <- index_h_filtered %>%
    filter(!is.na(算法) & grepl("FigureRate", 算法)) %>%
    pull(报告维度) %>%
    unique() %>%
    .[!is.na(.)]
if (length(rate_dims) > 0) {
    dat_stu_h <- CalFigureRate(dat_stu_h, index_h_filtered, dim_list = rate_dims)
}


# 5.7-5.12 对子维度进行计算（与报告维度相同的逻辑）

# 5.7 计算均分（MEAN）- 子维度
dat_stu_h <- Cal_MEAN(dat_stu_h, index_h_subdim, dim_col = "子维度")

# 5.8 计算总分（SUM）- 子维度
dat_stu_h <- Cal_SUM(dat_stu_h, index_h_subdim, dim_col = "子维度")

# 5.9 根据选项分类（ClassChoice）- 子维度
dat_stu_h <- Cal_ClassChoice(dat_stu_h, index_h_subdim, dim_col = "子维度")

# 5.10 按阈值分类（ClassThreshold）- 子维度
# 获取需要ClassThreshold的子维度列表
threshold_subdims <- index_h_subdim %>%
    filter(!is.na(算法) & grepl("ClassThreshold", 算法)) %>%
    pull(子维度) %>%
    unique() %>%
    .[!is.na(.)]
if (length(threshold_subdims) > 0) {
    dat_stu_h <- Cal_ClassThreshold(dat_stu_h, index_h_subdim, dim_list = threshold_subdims, dim_col = "子维度")
}

# 5.11 根据类别计算指标（FigureClass）- 子维度
dat_stu_h <- Cal_FigureClass(dat_stu_h, index_h_subdim, dim_col = "子维度")

# 5.12 计算占比（FigureRate）- 子维度
# 获取需要FigureRate的子维度列表
rate_subdims <- index_h_subdim %>%
    filter(!is.na(算法) & grepl("FigureRate", 算法)) %>%
    pull(子维度) %>%
    unique() %>%
    .[!is.na(.)]
if (length(rate_subdims) > 0) {
    dat_stu_h <- CalFigureRate(dat_stu_h, index_h_subdim, dim_list = rate_subdims, dim_col = "子维度")
}

# 6 师生关系 需要多算一个Figure，ClassThreshold(3)
dat_stu_h <- dat_stu_h %>%
    mutate(师生关系_Figure = ifelse(师生关系_Score >= 3, 1, 0))


# 6、保存数据
write_xlsx(dat_stu_h, "8 cleaned data/1 h/1 【高中】学生家长数据表_20251229.xlsx")
write_xlsx(dat_stu_h[1:50,], "8 cleaned data/1 h/1 【高中】学生家长数据表_20251229_test.xlsx")
















########################################################
# 教师数据读入
########################################################

### 1、基础信息处理
# 区市 的顺序是：局属学校、西海岸新区、城阳区、即墨区、胶州市、平度市、莱西市
# Gen：性别levels = c("男", "女")
# Age：年龄levels = c("乡村", "镇驻地", "城区")
# Tit：职称
# Edu：学历
# Exp：教龄
index_item_tea <- index_h %>% filter(数据表名 == "教师问卷") 
# 去掉题目列名中的所有空白字符（包括空格、制表符、换行符、全角空格等），以便与dat_tea_h的列名匹配（dat_tea_h的列名已去掉空格）
# 使用更彻底的清理方式：先trimws去掉首尾空白，然后去掉所有空白字符
index_item_tea$题目列名 <- trimws(index_item_tea$题目列名)
index_item_tea$题目列名 <- gsub("[[:space:]]", "", index_item_tea$题目列名)
# 如果还有问题，尝试去掉所有Unicode空白字符
index_item_tea$题目列名 <- gsub("\\p{Z}", "", index_item_tea$题目列名, perl = TRUE)

dat_tea_h <- dat_tea_h_ori %>%
    rename_all(~ gsub("\\s+", "", .x)) %>%
    mutate(
        区市 = factor(区市, levels = c("局属学校", "西海岸新区", "城阳区", "即墨区", "胶州市", "平度市", "莱西市")),
        Gen = factor(`1.您的性别是（单选题）`, levels = c("男", "女")),
        # Age：年龄分组（20-29岁、30-39岁、40-49岁、50岁以上）
        Age = factor(case_when(
            as.numeric(`2.您的年龄是：_岁（只填写阿拉伯数字）（填空题）`) >= 20 & 
            as.numeric(`2.您的年龄是：_岁（只填写阿拉伯数字）（填空题）`) <= 29 ~ "20-29岁",
            as.numeric(`2.您的年龄是：_岁（只填写阿拉伯数字）（填空题）`) >= 30 & 
            as.numeric(`2.您的年龄是：_岁（只填写阿拉伯数字）（填空题）`) <= 39 ~ "30-39岁",
            as.numeric(`2.您的年龄是：_岁（只填写阿拉伯数字）（填空题）`) >= 40 & 
            as.numeric(`2.您的年龄是：_岁（只填写阿拉伯数字）（填空题）`) <= 49 ~ "40-49岁",
            as.numeric(`2.您的年龄是：_岁（只填写阿拉伯数字）（填空题）`) >= 50 ~ "50岁以上",
            TRUE ~ NA_character_
        ), levels = c("20-29岁", "30-39岁", "40-49岁", "50岁以上")),
        # Tit：职称（将"其他(国家二级心理咨询师)"和"其他(无)"转为"未定级"）
        Tit = factor(case_when(
            `7.您的职称是（单选题）` == "其他​(国家二级心理咨询师)" ~ "未定级",
            `7.您的职称是（单选题）` == "其他​(无)" ~ "未定级",
            TRUE ~ `7.您的职称是（单选题）`
        )),
        # Edu：学历分组（大专及以下、本科、研究生）
        Edu = factor(case_when(
            `4.您入职教师时的学历是（单选题）` %in% c("师范类大专", "非师范类大专", "高中(中专)及以下") ~ "大专及以下",
            `4.您入职教师时的学历是（单选题）` %in% c("师范类本科", "非师范类本科") ~ "本科",
            `4.您入职教师时的学历是（单选题）` == "硕士或博士研究生" ~ "研究生",
            TRUE ~ NA_character_
        ), levels = c("大专及以下", "本科", "研究生")),
        # Exp：教龄分组（5年及以下、6～15年、16～24年、25年以上）
        Exp = factor(case_when(
            as.numeric(`3.您任职教师的总年数是：_年（只填写阿拉伯数字，不满1.年的填写1年）（填空题）`) <= 5 ~ "5年及以下",
            as.numeric(`3.您任职教师的总年数是：_年（只填写阿拉伯数字，不满1.年的填写1年）（填空题）`) >= 6 & 
            as.numeric(`3.您任职教师的总年数是：_年（只填写阿拉伯数字，不满1.年的填写1年）（填空题）`) <= 15 ~ "6～15年",
            as.numeric(`3.您任职教师的总年数是：_年（只填写阿拉伯数字，不满1.年的填写1年）（填空题）`) >= 16 & 
            as.numeric(`3.您任职教师的总年数是：_年（只填写阿拉伯数字，不满1.年的填写1年）（填空题）`) <= 24 ~ "16～24年",
            as.numeric(`3.您任职教师的总年数是：_年（只填写阿拉伯数字，不满1.年的填写1年）（填空题）`) >= 25 ~ "25年以上",
            TRUE ~ NA_character_
        ), levels = c("5年及以下", "6～15年", "16～24年", "25年以上"))
    ) 


# table(dat_tea_h_ori$`14.最近的一个完整星期里，您花费_​小时(整数)用于本校教学？（填空题）`)
# table(dat_tea_h_ori$`3.您任职教师的总年数是：_年（只填写阿拉伯数字，不满1.年的填写1年）（填空题）`)


### 2、所有的量表题目，转为分数；
dat_tea_h <- dat_tea_h %>%
    mutate(across(contains("量表题"), ~ gsub("^([0-9]+)\\(.*$", "\\1", .))) %>%
    # 将所有量表题转换为数值型
    mutate(across(contains("量表题"), ~ as.numeric(.))) %>%
    mutate(
        # 教师每日教学时长：基于每周教学小时数，计算每日平均教学时长
        教师每日教学时长_Score = as.numeric(gsub("\\|", "", `14.最近的一个完整星期里，您花费_​小时(整数)用于本校教学？（填空题）`))/5,
        # 教师教学时长：基于每周教学小时数，分成4类
        教师教学时长 = {
            教学小时数 <- 教师每日教学时长_Score
            factor(case_when(
                教学小时数 < 2 ~ "不足2小时",
                教学小时数 >= 2 & 教学小时数 < 4 ~ "2~4小时（不含4小时）",
                教学小时数 >= 4 & 教学小时数 < 6 ~ "4~6小时（不含6小时）",
                教学小时数 >= 6 ~ "6小时以上",
                TRUE ~ NA_character_
            ), levels = c("不足2小时", "2~4小时（不含4小时）", "4~6小时（不含6小时）", "6小时以上"))
        }
    ) 
# 处理第16题：将填空题格式转换为多列格式
# 大题题干
q16_main <- "16.最近的一个完整星期里，您在本校的工作上大约花费了多少小时用于下列事务？（请填写阿拉伯数字）"
# 小题列表
q16_subitems <- c(
    "1.个人学习或备课",
    "2.与本校同事合作交流",
    "3.批改学生作业",
    "4.辅导学生(包括辅导、在线咨询、职业规划和行为规范指导)",
    "5.参与学校管理",
    "6.日常事务性工作(包括口头沟通、书面工作以及报表文书工作)",
    "7.专业发展活动(含教研活动)",
    "8.与家长或监护人的沟通与合作",
    "9.参与课外活动(例如放学后的课后服务)",
    "10.其他工作任务"
)
# 原始列名 
q16_original_col <- "16.最近的一个完整星期里，您在本校的工作上大约花费了多少小时用于下列事务？（请填写阿拉伯数字）.-1.个人学习或备课_​小时；.-2.与本校同事合作交流_​小时；.-3.批改学生作业_​小时；.-4.辅导学生(包括辅导、在线咨询、职业规划和行为规范指导)_​小时；.-5.参与学校管理_​小时；.-6.日常事务性工作(包括口头沟通、书面工作以及报表文书工作)_​小时；.-7.专业发展活动(含教研活动)_​小时；.-8.与家长或监护人的沟通与合作_​小时；.-9.参与课外活动(例如放学后的课后服务)_​小时；.-10.其他工作任务_​小时。（填空题）"

# 检查列是否存在
if (q16_original_col %in% colnames(dat_tea_h)) {
    # 分割字符串并创建新列
    for (i in seq_along(q16_subitems)) {
        new_col_name <- paste0(q16_main, "_", q16_subitems[i])
        dat_tea_h[[new_col_name]] <- sapply(dat_tea_h[[q16_original_col]], function(x) {
            if (is.na(x) || x == "") {
                return(NA_real_)
            }
            # 分割字符串（使用 |\r\n 或 |\n 作为分隔符）
            parts <- strsplit(as.character(x), "\\|\\r\\n|\\|\\n|\\|")[[1]]
            # 提取第i个部分并转换为数值
            if (length(parts) >= i) {
                val <- as.numeric(trimws(parts[i]))
                return(ifelse(is.na(val), NA_real_, val))
            } else {
                return(NA_real_)
            }
        })
    }
    # 删除原始列
    dat_tea_h[[q16_original_col]] <- NULL
} else {
    warning("未找到第16题的原始列")
}

# 3、多选题处理
dat_tea_h <- MultiChoice_to_Numeric(dat_tea_h, index_item_tea)

# 4、反向题处理：
# 筛选出需要反向的题目
reverse_items <- index_item_tea %>%
    filter(!is.na(是否反向) & 是否反向 == "R" ) %>%
    pull(题目列名)

# 对每个反向题进行处理
for (col_name in reverse_items) {
    # 检查列是否存在
    if (col_name %in% colnames(dat_tea_h)) {
        # 先复制原列到新列（反向前）
        backup_col_name <- paste0(col_name, "_反向前")
        dat_tea_h[[backup_col_name]] <- dat_tea_h[[col_name]]
        
        # 将列转换为数值型
        dat_tea_h[[col_name]] <- as.numeric(dat_tea_h[[col_name]])
        
        # 找到最大值（排除NA）
        max_val <- max(dat_tea_h[[col_name]], na.rm = TRUE)
        
        # 反向处理：用(最大值+1)减去原值
        dat_tea_h[[col_name]] <- (max_val + 1) - dat_tea_h[[col_name]]
    } else {
        # 如果找不到该列，打印题目列名但不影响循环
        cat("警告：在dat_tea_h中找不到列：", col_name, "\n")
    }
}


dat_tea_h <- dat_tea_h %>%
    # 焦虑和抑郁：包含特定字符串的列，所有值减去1 (❗️此处需要在反向后操作)
    mutate(across(contains("60.下面是人们常有的一些感受。在最近一周，您大约几天有过以下感受？（量表题）"), 
                  ~ as.numeric(.) - 1)) %>%
    mutate(across(contains("61.在最近2周里，您是否经常有下列感受？请根据您真实感受选择。（量表题）"), 
                  ~ as.numeric(.) - 1))

# 5、计算维度分数和分类

# 5.1 计算均分（MEAN）
dat_tea_h <- Cal_MEAN(dat_tea_h, index_item_tea)

# 5.2 计算总分（SUM）
dat_tea_h <- Cal_SUM(dat_tea_h, index_item_tea)

# 5.3 根据选项分类（ClassChoice）
dat_tea_h <- Cal_ClassChoice(dat_tea_h, index_item_tea)

# 5.4 按阈值分类（ClassThreshold）
# 获取需要ClassThreshold的维度列表
threshold_dims <- index_item_tea %>%
    filter(!is.na(算法) & grepl("ClassThreshold", 算法)) %>%
    pull(报告维度) %>%
    unique() %>%
    .[!is.na(.)]
if (length(threshold_dims) > 0) {
    dat_tea_h <- Cal_ClassThreshold(dat_tea_h, index_item_tea, dim_list = threshold_dims)
}

# 5.5 根据类别计算指标（FigureClass）
dat_tea_h <- Cal_FigureClass(dat_tea_h, index_item_tea)

# 5.6 计算占比（FigureRate）
# 获取需要FigureRate的维度列表
rate_dims <- index_item_tea %>%
    filter(!is.na(算法) & grepl("FigureRate", 算法)) %>%
    pull(报告维度) %>%
    unique() %>%
    .[!is.na(.)]
if (length(rate_dims) > 0) {
    dat_tea_h <- CalFigureRate(dat_tea_h, index_item_tea, dim_list = rate_dims)
}


# 5.7-5.12 对子维度进行计算（与报告维度相同的逻辑）

# 5.7 计算均分（MEAN）- 子维度
dat_tea_h <- Cal_MEAN(dat_tea_h, index_item_tea, dim_col = "子维度")

# 5.8 计算总分（SUM）- 子维度
dat_tea_h <- Cal_SUM(dat_tea_h, index_item_tea, dim_col = "子维度")

# 5.9 根据选项分类（ClassChoice）- 子维度
dat_tea_h <- Cal_ClassChoice(dat_tea_h, index_item_tea, dim_col = "子维度")

# 5.10 按阈值分类（ClassThreshold）- 子维度
# 获取需要ClassThreshold的子维度列表
threshold_subdims <- index_item_tea %>%
    filter(!is.na(算法) & grepl("ClassThreshold", 算法)) %>%
    pull(子维度) %>%
    unique() %>%
    .[!is.na(.)]
if (length(threshold_subdims) > 0) {
    dat_tea_h <- Cal_ClassThreshold(dat_tea_h, index_item_tea, dim_list = threshold_subdims, dim_col = "子维度")
}

# 5.11 根据类别计算指标（FigureClass）- 子维度
dat_tea_h <- Cal_FigureClass(dat_tea_h, index_item_tea, dim_col = "子维度")

# 5.12 计算占比（FigureRate）- 子维度
# 获取需要FigureRate的子维度列表
rate_subdims <- index_item_tea %>%
    filter(!is.na(算法) & grepl("FigureRate", 算法)) %>%
    pull(子维度) %>%
    unique() %>%
    .[!is.na(.)]
if (length(rate_subdims) > 0) {
    dat_tea_h <- CalFigureRate(dat_tea_h, index_item_tea, dim_list = rate_subdims, dim_col = "子维度")
}

# 5.13 特殊变量，相关用
# 先获取包含引号的列名
col_58_name <- colnames(dat_tea_h)[grepl("58.周一至周五.*可填.*0.*填空题", colnames(dat_tea_h))]
col_59_name <- colnames(dat_tea_h)[grepl("59.周六日.*可填.*0.*填空题", colnames(dat_tea_h))]

dat_tea_h <- dat_tea_h %>%
    mutate(
        # 年收入：从最低到高编码为1、2、3...
        年收入_Score = case_when(
            `8.您过去一年全部收入(含各种奖金)大概多少？（单选题）` == "8000元及以下" ~ 1,
            `8.您过去一年全部收入(含各种奖金)大概多少？（单选题）` == "8000-18000元" ~ 2,
            `8.您过去一年全部收入(含各种奖金)大概多少？（单选题）` == "18001-29000元" ~ 3,
            `8.您过去一年全部收入(含各种奖金)大概多少？（单选题）` == "29001-45000元" ~ 4,
            `8.您过去一年全部收入(含各种奖金)大概多少？（单选题）` == "45001-85000元" ~ 5,
            `8.您过去一年全部收入(含各种奖金)大概多少？（单选题）` == "85001元及以上" ~ 6,
            TRUE ~ NA_real_
        ),
        
        # 睡眠质量：保留第一位数字，转为numeric
        睡眠质量_Score = as.numeric(substr(`57.过去一周，您的睡眠质量如何？（下拉单选题）`, 1, 1)),
        
        # 工作日睡眠时长：从第55题提取4个值（上床睡觉时、分；起床时、分），计算睡眠时长
        工作日睡眠时长_Score = {
            # 提取第55题的列名
            col_55 <- `55.在周一到周五上班的日子，您通常几点起床：_​时_​分（若填写00、01个位数时，请直接填写0、1字眼，下同）；通常几点上床睡觉：_​时_​分（时间请按照24小时制，如晚上10点，请填写22点）.（填空题）`
            # 先替换掉_x000D_和可能的换行符，然后用|分割
            col_55_clean <- gsub("_x000D_", "", as.character(col_55))
            col_55_clean <- gsub("\\\\n|\\n", "", col_55_clean)
            parts <- strsplit(col_55_clean, "|", fixed = TRUE)
            # 提取4个值：前两个是起床时、分；后两个是上床睡觉时、分
            wake_hour <- as.numeric(sapply(parts, function(x) if(length(x) >= 1 && x[1] != "") x[1] else NA))
            wake_min <- as.numeric(sapply(parts, function(x) if(length(x) >= 2 && x[2] != "") x[2] else NA))
            sleep_hour <- as.numeric(sapply(parts, function(x) if(length(x) >= 3 && x[3] != "") x[3] else NA))
            sleep_min <- as.numeric(sapply(parts, function(x) if(length(x) >= 4 && x[4] != "") x[4] else NA))
            # 处理sleep_hour
            sleep_hour_adj <- ifelse(sleep_hour >= 8 & sleep_hour <= 11, sleep_hour + 12,
                                    ifelse(sleep_hour == 12, 0, sleep_hour))
            
            # 计算睡眠时长（分钟）
            sleep_time_min <- ifelse(sleep_hour_adj > 17,
                                    # 如果sleep_hour > 17：先算零点后睡了多久，加上零点前的
                                    (wake_hour * 60 + wake_min) + (24 - sleep_hour_adj) * 60 - sleep_min,
                                    ifelse(sleep_hour_adj < 8,
                                           # 如果sleep_hour < 8：直接相减
                                           (wake_hour * 60 + wake_min) - (sleep_hour_adj * 60 + sleep_min),
                                           NA_real_))  # 其他情况返回NA
            
            # 转换为小时（保留2位小数）
            sleep_time_hours <- round(sleep_time_min / 60, 2)
            # 将 <= 2 的值转为NA
            ifelse(sleep_time_hours <= 2 | sleep_time_hours >= 15, NA_real_, sleep_time_hours)
        },
        
        # 工作日工作时长：去掉"|"并转为数值，超过24转为NA
        工作日工作时长_Score = {
            work_hours <- as.numeric(gsub("\\|", "", .data[[col_58_name]]))
            ifelse(work_hours > 24, NA_real_, work_hours)
        },
        
        # 周末工作时长：转为数值，超过24转为NA
        周末工作时长_Score = {
            weekend_hours <- as.numeric(.data[[col_59_name]])
            ifelse(weekend_hours > 24, NA_real_, weekend_hours)
        }
    )
# 6、保存数据
write_xlsx(dat_tea_h, "8 cleaned data/1 h/2 【高中】教师数据表_20251229.xlsx")
write_xlsx(dat_tea_h[1:50,], "8 cleaned data/1 h/2 【高中】教师数据表_20251229_test.xlsx")
# mean(dat_tea_h$积极成员_Score, na.rm = TRUE)















########################################################
# 转为SPSS数据格式
########################################################

# 1 单选题选项转化为数字
dat_stu_h_spss <- SingleChoice_to_Numeric(dat_stu_h, index_h_filtered)


# 1.1 为单选题添加值标签（情况2）
single_choice_rows <- index_h_filtered %>%
    filter(!is.na(题型) & 题型 == "单选题")
for (i in seq_len(nrow(single_choice_rows))) {
    item_name <- single_choice_rows[["题目列名"]][i]
    if (is.na(item_name) || !item_name %in% colnames(dat_stu_h_spss)) next
    
    option_str <- single_choice_rows[["选项"]][i]
    if (is.na(option_str) || option_str == "") next
    
    # 用//C//分割选项
    options_raw <- strsplit(option_str, "//C//", fixed = TRUE)[[1]]
    options_raw <- trimws(options_raw)
    
    # 处理选项：提取选项名称（处理包含"_______"的情况）
    options <- character(length(options_raw))
    for (j in seq_along(options_raw)) {
        opt <- options_raw[j]
        if (grepl("_______", opt, fixed = TRUE)) {
            options[j] <- trimws(strsplit(opt, "_______", fixed = TRUE)[[1]][1])
        } else {
            options[j] <- opt
        }
    }
    
    # 创建值标签：1=选项1, 2=选项2, ...
    value_labels <- setNames(seq_along(options), options)
    attr(dat_stu_h_spss[[item_name]], "labels") <- value_labels
}


# 2 反向题的列名添加"_反向后"
# 获取所有反向题的列名
reverse_cols <- reverse_items[reverse_items %in% colnames(dat_stu_h_spss)]
for (col_name in reverse_cols) {
    new_col_name <- paste0(col_name, "_反向后")
        # 重命名列
        colnames(dat_stu_h_spss)[colnames(dat_stu_h_spss) == col_name] <- new_col_name
}

# 3 多选题没有添加选项的列，也就是与原题目列名完全匹配的列，去掉
# 获取所有多选题的题目列名
multi_choice_items <- index_h_filtered %>%
    filter(!is.na(题型) & 题型 == "多选题") %>%
    pull(题目列名) %>%
    unique() %>%
    .[!is.na(.)]

# 3.1 为多选题添加值标签（情况1）
# 查找所有多选题的选项列（格式：题目列名_选项）
for (item_name in multi_choice_items) {
    if (!item_name %in% colnames(dat_stu_h_spss)) next
    
    # 查找该题目的所有选项列
    option_cols <- colnames(dat_stu_h_spss)[grepl(paste0("^", gsub("([.^$*+?(){}[\\|])", "\\\\\\1", item_name), "_"), colnames(dat_stu_h_spss))]
    
    # 为每个选项列添加值标签：1=选中, 0=未选中
    for (opt_col in option_cols) {
        value_labels <- c("未选中" = 0, "选中" = 1)
        attr(dat_stu_h_spss[[opt_col]], "labels") <- value_labels
    }
}

# 删除这些原始多选题列（如果存在）
multi_choice_cols_to_remove <- multi_choice_items[multi_choice_items %in% colnames(dat_stu_h_spss)]
if (length(multi_choice_cols_to_remove) > 0) {
    dat_stu_h_spss <- dat_stu_h_spss[, !colnames(dat_stu_h_spss) %in% multi_choice_cols_to_remove]
}

# 4 所有的"_Class"列，都需要在index表中，找到【报告维度分类名1】、【报告维度分类名2】等列，按照这个顺序，把分类名字转为数字。
# 例如，某学生在【人际支持_Class】中为"不达标"，【人际支持】维度在index表中【报告维度分类名1】为"不达标"，【报告维度分类名2】为"达标"，那么【人际支持_Class】应该转为1。
# 获取所有_Class列
class_cols <- colnames(dat_stu_h_spss)[grepl("_Class$", colnames(dat_stu_h_spss))]
for (class_col in class_cols) {
    # 提取维度名称（去掉_Class后缀）
    dim_name <- gsub("_Class$", "", class_col)
    
    # 在index中查找该维度的分类名
    dim_rows <- index_h_filtered %>%
        filter(报告维度 == dim_name | 子维度 == dim_name)
    
    if (nrow(dim_rows) > 0) {
        # 获取分类名（报告维度分类名1, 报告维度分类名2, ...）
        class_names <- character(0)
        i <- 1
        while (TRUE) {
            class_name_col <- paste0("报告维度分类名", i)
            if (class_name_col %in% colnames(dim_rows)) {
                class_name_val <- dim_rows[[class_name_col]][1]
                if (!is.na(class_name_val) && class_name_val != "") {
                    class_names <- c(class_names, class_name_val)
                    i <- i + 1
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        # 如果有分类名，则进行转换
        if (length(class_names) > 0) {
            dat_stu_h_spss[[class_col]] <- sapply(dat_stu_h_spss[[class_col]], function(x) {
                if (is.na(x)) return(NA_real_)
                match_idx <- which(class_names == as.character(x))
                if (length(match_idx) > 0) {
                    return(as.numeric(match_idx[1]))
                } else {
                    return(NA_real_)
                }
            })
            
            # 记录值标签信息（情况4）
            value_labels <- setNames(seq_along(class_names), class_names)
            attr(dat_stu_h_spss[[class_col]], "labels") <- value_labels
        }
    }
}

# 4.1 为量表题添加值标签（情况3）
# 获取所有包含"量表题"的列
scale_cols <- colnames(dat_stu_h_spss)[grepl("量表题", colnames(dat_stu_h_spss))]
# 获取所有反向前和反向后列
reverse_before_cols <- colnames(dat_stu_h_spss)[grepl("_反向前$", colnames(dat_stu_h_spss))]
reverse_after_cols <- colnames(dat_stu_h_spss)[grepl("_反向后$", colnames(dat_stu_h_spss))]

# 处理反向前列
for (col_name in reverse_before_cols) {
    # 提取原始题目列名（去掉_反向前后缀）
    original_name <- gsub("_反向前$", "", col_name)
    
    # 在index中查找该题目
    item_rows <- index_h_filtered %>%
        filter(题目列名 == original_name)
    
    if (nrow(item_rows) > 0) {
        option_str <- item_rows[["选项"]][1]
        if (!is.na(option_str) && option_str != "") {
            # 用//C//分割选项
            options_raw <- strsplit(option_str, "//C//", fixed = TRUE)[[1]]
            options_raw <- trimws(options_raw)
            
            # 处理选项：提取选项名称（处理包含"_______"的情况）
            options <- character(length(options_raw))
            for (j in seq_along(options_raw)) {
                opt <- options_raw[j]
                if (grepl("_______", opt, fixed = TRUE)) {
                    options[j] <- trimws(strsplit(opt, "_______", fixed = TRUE)[[1]][1])
                } else {
                    options[j] <- opt
                }
            }
            
            # 创建值标签：按照选项顺序（1=选项1, 2=选项2, ...）
            value_labels <- setNames(seq_along(options), options)
            attr(dat_stu_h_spss[[col_name]], "labels") <- value_labels
        }
    }
}

# 处理反向后列
for (col_name in reverse_after_cols) {
    # 提取原始题目列名（去掉_反向后后缀）
    original_name <- gsub("_反向后$", "", col_name)
    
    # 在index中查找该题目
    item_rows <- index_h_filtered %>%
        filter(题目列名 == original_name)
    
    if (nrow(item_rows) > 0) {
        option_str <- item_rows[["选项"]][1]
        if (!is.na(option_str) && option_str != "") {
            # 用//C//分割选项
            options_raw <- strsplit(option_str, "//C//", fixed = TRUE)[[1]]
            options_raw <- trimws(options_raw)
            
            # 处理选项：提取选项名称（处理包含"_______"的情况）
            options <- character(length(options_raw))
            for (j in seq_along(options_raw)) {
                opt <- options_raw[j]
                if (grepl("_______", opt, fixed = TRUE)) {
                    options[j] <- trimws(strsplit(opt, "_______", fixed = TRUE)[[1]][1])
                } else {
                    options[j] <- opt
                }
            }
            
            # 创建值标签：按照选项顺序反向（5=选项1, 4=选项2, ..., 1=选项5）
            n_options <- length(options)
            value_labels <- setNames(n_options:1, options)
            attr(dat_stu_h_spss[[col_name]], "labels") <- value_labels
        }
    }
}

# 处理没有反向标签的量表题
for (col_name in scale_cols) {
    # 跳过已经处理过的反向前和反向后列
    if (col_name %in% reverse_before_cols || col_name %in% reverse_after_cols) next
    
    # 在index中查找该题目
    item_rows <- index_h_filtered %>%
        filter(题目列名 == col_name)
    
    if (nrow(item_rows) > 0) {
        # 检查是否有反向标签
        is_reverse <- !is.na(item_rows[["是否反向"]][1]) && item_rows[["是否反向"]][1] == "R"
        
        option_str <- item_rows[["选项"]][1]
        if (!is.na(option_str) && option_str != "") {
            # 用//C//分割选项
            options_raw <- strsplit(option_str, "//C//", fixed = TRUE)[[1]]
            options_raw <- trimws(options_raw)
            
            # 处理选项：提取选项名称（处理包含"_______"的情况）
            options <- character(length(options_raw))
            for (j in seq_along(options_raw)) {
                opt <- options_raw[j]
                if (grepl("_______", opt, fixed = TRUE)) {
                    options[j] <- trimws(strsplit(opt, "_______", fixed = TRUE)[[1]][1])
                } else {
                    options[j] <- opt
                }
            }
            
            if (is_reverse) {
                # 反向后：按照选项顺序反向
                n_options <- length(options)
                value_labels <- setNames(n_options:1, options)
            } else {
                # 反向前或没有反向：按照选项顺序
                value_labels <- setNames(seq_along(options), options)
            }
            attr(dat_stu_h_spss[[col_name]], "labels") <- value_labels
        }
    }
}

# 5 清理列名使其符合SPSS变量名规范
# 保存原始列名（用于变量标签）
original_colnames <- colnames(dat_stu_h_spss)

# 保存值标签信息（在清理列名之前）
value_labels_list <- list()
for (i in seq_along(colnames(dat_stu_h_spss))) {
    col_name <- colnames(dat_stu_h_spss)[i]
    if (!is.null(attr(dat_stu_h_spss[[col_name]], "labels"))) {
        value_labels_list[[col_name]] <- attr(dat_stu_h_spss[[col_name]], "labels")
    }
}

# 清理列名
new_colnames <- clean_spss_names(colnames(dat_stu_h_spss))
colnames(dat_stu_h_spss) <- new_colnames

# 重新应用值标签（因为列名改变了）
for (i in seq_along(new_colnames)) {
    old_col_name <- original_colnames[i]
    new_col_name <- new_colnames[i]
    
    # 应用变量标签（原始列名）
    attr(dat_stu_h_spss[[new_col_name]], "label") <- old_col_name
    
    # 应用值标签（如果有）
    if (old_col_name %in% names(value_labels_list)) {
        attr(dat_stu_h_spss[[new_col_name]], "labels") <- value_labels_list[[old_col_name]]
    }
}

# 5.1 重新排列列的顺序
# 获取当前所有列名
all_cols <- colnames(dat_stu_h_spss)

# 1. 识别前8个变量（Var1到Var8，或前8列）
first_8_cols <- all_cols[seq_len(min(8, length(all_cols)))]

# 2. 识别Score_、_Class_、_Figure_列（留在最后）
score_class_figure_cols <- all_cols[grepl("_Score$|_Class$|_Figure$", all_cols)]

# 3. 其他列：按照index_h中的题目列名顺序排列（保持index_h的原始行顺序）
# 获取index_h中所有题目列名的顺序（学生问卷和家长问卷，保持原始行顺序）
index_item_order <- index_h_filtered %>%
    pull(题目列名) %>%
    .[!is.na(.)] %>%
    unique()

# 创建列名到原始列名的映射（用于匹配）
colname_to_original <- setNames(original_colnames, new_colnames)

# 按照index_h的顺序排列其他列
other_cols <- all_cols[!all_cols %in% c(first_8_cols, score_class_figure_cols)]
ordered_other_cols <- character(0)

# 按照index_h的顺序添加列
for (item_name in index_item_order) {
    # 查找匹配的列（可能是原始列名，也可能是多选题的选项列）
    matching_cols <- other_cols[sapply(other_cols, function(col) {
        original <- colname_to_original[[col]]
        if (is.null(original)) return(FALSE)
        # 精确匹配
        if (original == item_name) return(TRUE)
        # 多选题选项列（以题目列名_开头）
        item_escaped <- gsub("([.^$*+?(){}[\\|])", "\\\\\\1", item_name)
        if (grepl(paste0("^", item_escaped, "_"), original)) return(TRUE)
        return(FALSE)
    })]
    # 将匹配的列从other_cols中移除，避免重复
    other_cols <- other_cols[!other_cols %in% matching_cols]
    ordered_other_cols <- c(ordered_other_cols, matching_cols)
}

# 添加剩余的列（不在index_h中的，已经自动从other_cols中移除未匹配的）
ordered_other_cols <- c(ordered_other_cols, other_cols)

# 4. 组合最终列顺序：前8列 + 按index_h排序的其他列 + Score/Class/Figure列
final_col_order <- c(first_8_cols, ordered_other_cols, score_class_figure_cols)

# 确保所有列都在final_col_order中（防止遗漏）
missing_cols <- all_cols[!all_cols %in% final_col_order]
if (length(missing_cols) > 0) {
    final_col_order <- c(final_col_order, missing_cols)
}

# 重新排列列
dat_stu_h_spss <- dat_stu_h_spss[, final_col_order]

# 6 保存数据
library(haven)
write_sav(dat_stu_h_spss, "8 cleaned data/1 h/1 【高中】学生家长数据表_20251229.sav")


########################################################
# 教师数据转为SPSS数据格式
########################################################

# 确保index_item_tea的题目列名已去掉空格（与dat_tea_h的列名匹配）
# 使用更彻底的清理方式：先trimws去掉首尾空白，然后去掉所有空白字符（包括全角空格、不间断空格等）
index_item_tea$题目列名 <- trimws(index_item_tea$题目列名)
index_item_tea$题目列名 <- gsub("[[:space:]]", "", index_item_tea$题目列名)
# 如果还有问题，尝试去掉所有Unicode空白字符
index_item_tea$题目列名 <- gsub("\\p{Z}", "", index_item_tea$题目列名, perl = TRUE)
# 1 单选题选项转化为数字
dat_tea_h_spss <- SingleChoice_to_Numeric(dat_tea_h, index_item_tea)


# 1.1 为单选题添加值标签（情况2）
single_choice_rows <- index_item_tea %>%
    filter(!is.na(题型) & 题型 == "单选题")
for (i in seq_len(nrow(single_choice_rows))) {
    item_name <- single_choice_rows[["题目列名"]][i]
    if (is.na(item_name) || !item_name %in% colnames(dat_tea_h_spss)) next
    
    option_str <- single_choice_rows[["选项"]][i]
    if (is.na(option_str) || option_str == "") next
    
    # 用//C//分割选项
    options_raw <- strsplit(option_str, "//C//", fixed = TRUE)[[1]]
    options_raw <- trimws(options_raw)
    
    # 处理选项：提取选项名称（处理包含"_______"的情况）
    options <- character(length(options_raw))
    for (j in seq_along(options_raw)) {
        opt <- options_raw[j]
        if (grepl("_______", opt, fixed = TRUE)) {
            options[j] <- trimws(strsplit(opt, "_______", fixed = TRUE)[[1]][1])
        } else {
            options[j] <- opt
        }
    }
    
    # 创建值标签：1=选项1, 2=选项2, ...
    value_labels <- setNames(seq_along(options), options)
    attr(dat_tea_h_spss[[item_name]], "labels") <- value_labels
}


# 2 反向题的列名添加"_反向后"
# 获取所有反向题的列名（教师数据中反向题已经创建了"_反向前"列，需要将原列重命名为"_反向后"）
reverse_items_tea <- index_item_tea %>%
    filter(!is.na(是否反向) & 是否反向 == "R") %>%
    pull(题目列名)
reverse_cols_tea <- reverse_items_tea[reverse_items_tea %in% colnames(dat_tea_h_spss)]
for (col_name in reverse_cols_tea) {
    new_col_name <- paste0(col_name, "_反向后")
    # 重命名列
    colnames(dat_tea_h_spss)[colnames(dat_tea_h_spss) == col_name] <- new_col_name
}

# 3 多选题没有添加选项的列，也就是与原题目列名完全匹配的列，去掉
# 获取所有多选题的题目列名
multi_choice_items_tea <- index_item_tea %>%
    filter(!is.na(题型) & 题型 == "多选题") %>%
    pull(题目列名) %>%
    unique() %>%
    .[!is.na(.)]

# 3.1 为多选题添加值标签（情况1）
# 查找所有多选题的选项列（格式：题目列名_选项）
for (item_name in multi_choice_items_tea) {
    if (!item_name %in% colnames(dat_tea_h_spss)) next
    
    # 查找该题目的所有选项列
    option_cols <- colnames(dat_tea_h_spss)[grepl(paste0("^", gsub("([.^$*+?(){}[\\|])", "\\\\\\1", item_name), "_"), colnames(dat_tea_h_spss))]
    
    # 为每个选项列添加值标签：1=选中, 0=未选中
    for (opt_col in option_cols) {
        value_labels <- c("未选中" = 0, "选中" = 1)
        attr(dat_tea_h_spss[[opt_col]], "labels") <- value_labels
    }
}

# 删除这些原始多选题列（如果存在）
multi_choice_cols_to_remove_tea <- multi_choice_items_tea[multi_choice_items_tea %in% colnames(dat_tea_h_spss)]
if (length(multi_choice_cols_to_remove_tea) > 0) {
    dat_tea_h_spss <- dat_tea_h_spss[, !colnames(dat_tea_h_spss) %in% multi_choice_cols_to_remove_tea]
}

# 4 所有的"_Class"列，都需要在index表中，找到【报告维度分类名1】、【报告维度分类名2】等列，按照这个顺序，把分类名字转为数字。
# 获取所有_Class列
class_cols_tea <- colnames(dat_tea_h_spss)[grepl("_Class$", colnames(dat_tea_h_spss))]
for (class_col in class_cols_tea) {
    # 提取维度名称（去掉_Class后缀）
    dim_name <- gsub("_Class$", "", class_col)
    
    # 在index中查找该维度的分类名
    dim_rows <- index_item_tea %>%
        filter(报告维度 == dim_name | 子维度 == dim_name)
    
    if (nrow(dim_rows) > 0) {
        # 获取分类名（报告维度分类名1, 报告维度分类名2, ...）
        class_names <- character(0)
        i <- 1
        while (TRUE) {
            class_name_col <- paste0("报告维度分类名", i)
            if (class_name_col %in% colnames(dim_rows)) {
                class_name_val <- dim_rows[[class_name_col]][1]
                if (!is.na(class_name_val) && class_name_val != "") {
                    class_names <- c(class_names, class_name_val)
                    i <- i + 1
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        # 如果有分类名，则进行转换
        if (length(class_names) > 0) {
            dat_tea_h_spss[[class_col]] <- sapply(dat_tea_h_spss[[class_col]], function(x) {
                if (is.na(x)) return(NA_real_)
                match_idx <- which(class_names == as.character(x))
                if (length(match_idx) > 0) {
                    return(as.numeric(match_idx[1]))
                } else {
                    return(NA_real_)
                }
            })
            
            # 记录值标签信息（情况4）
            value_labels <- setNames(seq_along(class_names), class_names)
            attr(dat_tea_h_spss[[class_col]], "labels") <- value_labels
        }
    }
}

# 4.1 为量表题添加值标签（情况3）
# 获取所有包含"量表题"的列
scale_cols_tea <- colnames(dat_tea_h_spss)[grepl("量表题", colnames(dat_tea_h_spss))]
# 获取所有反向前和反向后列
reverse_before_cols_tea <- colnames(dat_tea_h_spss)[grepl("_反向前$", colnames(dat_tea_h_spss))]
reverse_after_cols_tea <- colnames(dat_tea_h_spss)[grepl("_反向后$", colnames(dat_tea_h_spss))]

# 处理反向前列
for (col_name in reverse_before_cols_tea) {
    # 提取原始题目列名（去掉_反向前后缀）
    original_name <- gsub("_反向前$", "", col_name)
    
    # 在index中查找该题目
    item_rows <- index_item_tea %>%
        filter(题目列名 == original_name)
    
    if (nrow(item_rows) > 0) {
        option_str <- item_rows[["选项"]][1]
        if (!is.na(option_str) && option_str != "") {
            # 用//C//分割选项
            options_raw <- strsplit(option_str, "//C//", fixed = TRUE)[[1]]
            options_raw <- trimws(options_raw)
            
            # 处理选项：提取选项名称（处理包含"_______"的情况）
            options <- character(length(options_raw))
            for (j in seq_along(options_raw)) {
                opt <- options_raw[j]
                if (grepl("_______", opt, fixed = TRUE)) {
                    options[j] <- trimws(strsplit(opt, "_______", fixed = TRUE)[[1]][1])
                } else {
                    options[j] <- opt
                }
            }
            
            # 创建值标签：按照选项顺序（1=选项1, 2=选项2, ...）
            value_labels <- setNames(seq_along(options), options)
            attr(dat_tea_h_spss[[col_name]], "labels") <- value_labels
        }
    }
}

# 处理反向后列
for (col_name in reverse_after_cols_tea) {
    # 提取原始题目列名（去掉_反向后后缀）
    original_name <- gsub("_反向后$", "", col_name)
    
    # 在index中查找该题目
    item_rows <- index_item_tea %>%
        filter(题目列名 == original_name)
    
    if (nrow(item_rows) > 0) {
        option_str <- item_rows[["选项"]][1]
        if (!is.na(option_str) && option_str != "") {
            # 用//C//分割选项
            options_raw <- strsplit(option_str, "//C//", fixed = TRUE)[[1]]
            options_raw <- trimws(options_raw)
            
            # 处理选项：提取选项名称（处理包含"_______"的情况）
            options <- character(length(options_raw))
            for (j in seq_along(options_raw)) {
                opt <- options_raw[j]
                if (grepl("_______", opt, fixed = TRUE)) {
                    options[j] <- trimws(strsplit(opt, "_______", fixed = TRUE)[[1]][1])
                } else {
                    options[j] <- opt
                }
            }
            
            # 创建值标签：按照选项顺序反向（5=选项1, 4=选项2, ..., 1=选项5）
            n_options <- length(options)
            value_labels <- setNames(n_options:1, options)
            attr(dat_tea_h_spss[[col_name]], "labels") <- value_labels
        }
    }
}

# 处理没有反向标签的量表题
for (col_name in scale_cols_tea) {
    # 跳过已经处理过的反向前和反向后列
    if (col_name %in% reverse_before_cols_tea || col_name %in% reverse_after_cols_tea) next
    
    # 在index中查找该题目
    item_rows <- index_item_tea %>%
        filter(题目列名 == col_name)
    
    if (nrow(item_rows) > 0) {
        # 检查是否有反向标签
        is_reverse <- !is.na(item_rows[["是否反向"]][1]) && item_rows[["是否反向"]][1] == "R"
        
        option_str <- item_rows[["选项"]][1]
        if (!is.na(option_str) && option_str != "") {
            # 用//C//分割选项
            options_raw <- strsplit(option_str, "//C//", fixed = TRUE)[[1]]
            options_raw <- trimws(options_raw)
            
            # 处理选项：提取选项名称（处理包含"_______"的情况）
            options <- character(length(options_raw))
            for (j in seq_along(options_raw)) {
                opt <- options_raw[j]
                if (grepl("_______", opt, fixed = TRUE)) {
                    options[j] <- trimws(strsplit(opt, "_______", fixed = TRUE)[[1]][1])
                } else {
                    options[j] <- opt
                }
            }
            
            if (is_reverse) {
                # 反向后：按照选项顺序反向
                n_options <- length(options)
                value_labels <- setNames(n_options:1, options)
            } else {
                # 反向前或没有反向：按照选项顺序
                value_labels <- setNames(seq_along(options), options)
            }
            attr(dat_tea_h_spss[[col_name]], "labels") <- value_labels
        }
    }
}

# 5 清理列名使其符合SPSS变量名规范
# 保存原始列名（用于变量标签）
original_colnames_tea <- colnames(dat_tea_h_spss)

# 保存值标签信息（在清理列名之前）
value_labels_list_tea <- list()
for (i in seq_along(colnames(dat_tea_h_spss))) {
    col_name <- colnames(dat_tea_h_spss)[i]
    if (!is.null(attr(dat_tea_h_spss[[col_name]], "labels"))) {
        value_labels_list_tea[[col_name]] <- attr(dat_tea_h_spss[[col_name]], "labels")
    }
}

# 清理列名
new_colnames_tea <- clean_spss_names(colnames(dat_tea_h_spss))
colnames(dat_tea_h_spss) <- new_colnames_tea

# 重新应用值标签（因为列名改变了）
for (i in seq_along(new_colnames_tea)) {
    old_col_name <- original_colnames_tea[i]
    new_col_name <- new_colnames_tea[i]
    
    # 应用变量标签（原始列名）
    attr(dat_tea_h_spss[[new_col_name]], "label") <- old_col_name
    
    # 应用值标签（如果有）
    if (old_col_name %in% names(value_labels_list_tea)) {
        attr(dat_tea_h_spss[[new_col_name]], "labels") <- value_labels_list_tea[[old_col_name]]
    }
}

# 5.1 重新排列列的顺序
# 获取当前所有列名
all_cols_tea <- colnames(dat_tea_h_spss)

# 1. 识别前8个变量（Var1到Var8，或前8列）
first_8_cols_tea <- all_cols_tea[seq_len(min(8, length(all_cols_tea)))]

# 2. 识别Score_、_Class_、_Figure_列（留在最后）
score_class_figure_cols_tea <- all_cols_tea[grepl("_Score$|_Class$|_Figure$", all_cols_tea)]

# 3. 其他列：按照index_item_tea中的题目列名顺序排列（保持index_item_tea的原始行顺序）
# 获取index_item_tea中所有题目列名的顺序（保持原始行顺序）
index_item_order_tea <- index_item_tea %>%
    pull(题目列名) %>%
    .[!is.na(.)] %>%
    unique()

# 创建列名到原始列名的映射（用于匹配）
colname_to_original_tea <- setNames(original_colnames_tea, new_colnames_tea)

# 按照index_item_tea的顺序排列其他列
other_cols_tea <- all_cols_tea[!all_cols_tea %in% c(first_8_cols_tea, score_class_figure_cols_tea)]
ordered_other_cols_tea <- character(0)

# 按照index_item_tea的顺序添加列
for (item_name in index_item_order_tea) {
    # 查找匹配的列（可能是原始列名，也可能是多选题的选项列）
    matching_cols <- other_cols_tea[sapply(other_cols_tea, function(col) {
        original <- colname_to_original_tea[[col]]
        if (is.null(original)) return(FALSE)
        # 精确匹配
        if (original == item_name) return(TRUE)
        # 多选题选项列（以题目列名_开头）
        item_escaped <- gsub("([.^$*+?(){}[\\|])", "\\\\\\1", item_name)
        if (grepl(paste0("^", item_escaped, "_"), original)) return(TRUE)
        return(FALSE)
    })]
    # 将匹配的列从other_cols_tea中移除，避免重复
    other_cols_tea <- other_cols_tea[!other_cols_tea %in% matching_cols]
    ordered_other_cols_tea <- c(ordered_other_cols_tea, matching_cols)
}

# 添加剩余的列（不在index_item_tea中的，已经自动从other_cols_tea中移除未匹配的）
ordered_other_cols_tea <- c(ordered_other_cols_tea, other_cols_tea)

# 4. 组合最终列顺序：前8列 + 按index_item_tea排序的其他列 + Score/Class/Figure列
final_col_order_tea <- c(first_8_cols_tea, ordered_other_cols_tea, score_class_figure_cols_tea)

# 确保所有列都在final_col_order_tea中（防止遗漏）
missing_cols_tea <- all_cols_tea[!all_cols_tea %in% final_col_order_tea]
if (length(missing_cols_tea) > 0) {
    final_col_order_tea <- c(final_col_order_tea, missing_cols_tea)
}

# 重新排列列
dat_tea_h_spss <- dat_tea_h_spss[, final_col_order_tea]

# 6 保存数据
write_sav(dat_tea_h_spss, "8 cleaned data/1 h/2 【高中】教师数据表_20251229.sav")




