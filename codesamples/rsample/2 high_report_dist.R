rm(list = ls())
# setwd("/Users/sonyalsonyal/Library/Mobile Documents/com~apple~CloudDocs/狗生4 - SRT/16 青岛3学段")
setwd("/Users/sonyal/Library/Mobile Documents/com~apple~CloudDocs/狗生4 - SRT/16 青岛3学段")
########################################################
# 包+函数+数据读入
########################################################
source("2 code/0_functions.R")
library(openxlsx)
library(dplyr)
library(writexl)
library(officer)
library(showtext)
library(ggplot2)
library(grid)

### 学生数据读入+必要设置
dat_stu <- read.xlsx("8 cleaned data/1 h/1 【高中】学生家长数据表_20251229.xlsx") %>%
    rename_all(~ gsub('xml:space="preserve">', '', .x, fixed = TRUE)) %>%
    rename_all(~ gsub('xml:space="preserve"', '', .x, fixed = TRUE)) %>%
    mutate(across(where(is.character), ~ gsub('xml:space="preserve">', '', .x, fixed = TRUE))) %>%
    mutate(across(where(is.character), ~ gsub('xml:space="preserve"', '', .x, fixed = TRUE))) %>%
    mutate(across(where(is.character), ~ trimws(.x)))
# 重新设置 factor 变量的 levels（因为 Excel 文件不保存 factor 的 levels 信息）
# 只对存在的列进行转换，避免错误
dat_stu <- dat_stu %>%
    mutate(
        # 区市
        across(any_of("区市"), ~ factor(.x, levels = c("局属学校", "西海岸新区", "城阳区", "即墨区", "胶州市", "平度市", "莱西市"))),
        # 性别
        across(any_of("Gen"), ~ factor(.x, levels = c("男", "女"))),
        # 城乡
        across(any_of("Loc"), ~ factor(.x, levels = c("乡村", "镇驻地", "城区"))),
        # 家庭结构
        across(any_of("Fam"), ~ factor(.x, levels = c("完整家庭", "父母离婚", "父亲或母亲去世"))),
        # 子女数量（Sim）
        across(any_of("Sim"), ~ factor(.x, levels = c("独生子女", "二孩", "多孩"))),
        # 母亲学历
        across(any_of("Edu_m"), ~ factor(.x, levels = c("初中及以下", "高中", "大专", "大学本科及以上"))),
        # 父亲学历
        across(any_of("Edu_f"), ~ factor(.x, levels = c("初中及以下", "高中", "大专", "大学本科及以上"))),
        # 家庭教育投入
        across(any_of("SES"), ~ factor(.x, levels = c("较低", "较高"))),
        # 父母关系
        across(any_of("父母关系"), ~ factor(.x, levels = c("关系非常好", "关系较好", "关系一般及以下"))),
        # 父母鼓励行为
        across(any_of("父母鼓励行为"), ~ factor(.x, levels = c("符合", "不符合"))),
        # 特殊的三道量表题目
        across(any_of(c("亲子关系感知", "父母共处感受", "父母理解情况")), 
               ~ factor(.x, levels = c("很不符合", "不太符合", "比较符合", "很符合")))
    )

### 教师数据读入+必要设置
dat_tea <- read.xlsx("8 cleaned data/1 h/2 【高中】教师数据表_20251229.xlsx")%>%
    rename_all(~ gsub('xml:space="preserve">', '', .x, fixed = TRUE)) %>%
    rename_all(~ gsub('xml:space="preserve"', '', .x, fixed = TRUE)) %>%
    mutate(across(where(is.character), ~ gsub('xml:space="preserve">', '', .x, fixed = TRUE))) %>%
    mutate(across(where(is.character), ~ gsub('xml:space="preserve"', '', .x, fixed = TRUE))) %>%
    mutate(across(where(is.character), ~ trimws(.x)))

dat_tea <- dat_tea %>%
    mutate(
        区市 = factor(区市, levels = c("局属学校", "西海岸新区", "城阳区", "即墨区", "胶州市", "平度市", "莱西市")),
        Gen = factor(Gen, levels = c("男", "女")),
        Age = factor(Age, levels = c("20-29岁", "30-39岁", "40-49岁", "50岁以上")),
        Tit = factor(Tit, levels = c("未定级", "初级教师", "中级教师", "副高级教师", "正高级教师")),
        Edu = factor(Edu, levels = c("大专及以下", "本科", "研究生")),
        Exp = factor(Exp, levels = c("5年及以下", "6～15年", "16～24年", "25年以上"))
    ) 

### 索引数据读入+必要设置
index_item <- read.xlsx("3 index/1 【高中】青岛项目问卷题目信息表20260417-dis-fix.xlsx", sheet = "high_item", startRow = 2)%>%
    mutate(题目列名 = gsub("\\s+", "", 题目列名))
index_report <- read.xlsx("3 index/1 【高中】青岛项目问卷题目信息表20260417-dis-fix.xlsx", sheet = "high_report_dist")%>%
    mutate(报告维度 = gsub("\\s+", "", 报告维度)) %>%
    filter(是否有效 == 1)

# ### 测试用临时行
# sum(colnames(dat) %in% c("81.（多选题）本学期，你参加校外补习(含家教、补习班、辅导班)原因有哪些？（多选题）"))
# colnames(dat_tea)[grepl("5.（多选题）本学期你所交的主要学科是（多选题）", colnames(dat_tea), fixed = TRUE)]
# table(d)
# df_female <- dat_stu %>% filter(Gen == "男") 
# mean(df_female$抑郁倾向_Figure)
# table(dat_tea$`15.本学期，您的备课时间是否足够？（单选题）`)
# dat_tea$`25.（多选题）您最需要哪些专业培训？（多选题）`[grepl("理念",dat_tea$`25.（多选题）您最需要哪些专业培训？（多选题）`)]
# index_report <- index_report %>%
#     filter(图题表题 %in% c("学生的手机依赖检出率","学生的心理健康课程开设达标率"))
# index_report <- index_report[nrow(index_report),]
# # index_report_row <- index_report[which(str_detect(index_report$文本段落, "从任教学科来看，语文、数学、英语三门学科教师占比较高"))[1], ]
# index_report_row <- index_report[i,]


# 需要用区级数据的函数（函数本身不变）
use_dist_funs <- c("ANOVA_scores","bar_chart_years","correlation_matrix",
"correlation_point","linear_regression",
"multichoice_distribution","multichoice_distribution_non_percent","pie_distribution","pie_distribution_trans_bar",
"simple_bar_subdim_figures","simple_bar_subdim_score",
"stack_bar_subdim","table_basic_infor_figures",
"table_items","table_items_score",
"table_cnt_stu","table_cnt_tea", 
"table_dims_figures", "table_dims_figures_percent","table_dims_score"
)

# 需要添加动态文本的函数
text_need_funs <- c("multichoice_distribution","multichoice_distribution_non_percent","pie_distribution",
"simple_bar_dis_figures","simple_bar_dis_figures_percent","simple_bar_dis_score", "stack_bar_var_distribution")

### 颜色
color_palette <- list(
  color_1 = c("#6a99d0"),
  color_1_highlight = c("#D5B983"), # 主要用于特殊的那个青岛市
  color_2 = c("#6a99d0", "#BFAF6D"),
  color_2_evaluation = c("#6a99d0", "#A86D70"),
  color_3 = c("#6a99d0", "#BFAF6D", "#A86D70"),
  color_4 = c("#6a99d0", "#869EA3", "#D1BABE", "#A86D70"),
  color_5 = c("#6a99d0", "#869EA3", "#BFAF6D", "#E0AD5B", "#A86D70"),
  color_6 = c("#6a99d0", "#869EA3", "#BFAF6D", "#E0AD5B", "#D1BABE", "#A86D70"),
  color_7 = c("#6a99d0", "#869EA3", "#BFAF6D", "#E0AD5B", "#D5B983", "#D1BABE", "#A86D70"),
  color_8 = c("#6a99d0", "#869EA3", "#BFAF6D", "#E0AD5B", "#D5B983", "#D1BABE", "#A86D70", "#6a99d0"),
  color_9 = c("#6a99d0", "#869EA3", "#BFAF6D", "#E0AD5B", "#D5B983", "#D1BABE", "#A86D70", "#6a99d0", "#869EA3"),
  color_11 = c("#6a99d0", "#869EA3", "#BFAF6D", "#ddeed9", "#E0AD5B", "#D1BABE", "#A86D70", "#6a99d0", "#869EA3", "#BFAF6D", "#E0AD5B"),
  gradient_positive = c("#ddeed9", "#BFAF6D"),
  gradient_negative = c("#B7B7B7", "#9A4941")
)

### 通用变量
figures_with_dot <- c("抑郁倾向","焦虑倾向","手机依赖","抑郁情绪","焦虑情绪")
basic_vars <- c("区市", "Gen", "Loc", "Fam", "Sim", "Edu_m", "Edu_f", "SES", "Age", "Tit")

# table_cnt_stu和table_cnt_tea的配置
# 学生表格配置
table_cnt_stu_left_vars <- c("Gen", "Sim", "Edu_m")
table_cnt_stu_right_vars <- c("Sim", "Loc", "Edu_f")

# 教师表格配置
table_cnt_tea_left_vars <- c("Gen", "Age", "Edu")
table_cnt_tea_right_vars <- c("Exp", "Tit")

# 统一的变量名映射（用于table_cnt_stu和table_cnt_tea）
var_name_mapping <- c(
    "Gen" = "性别",
    "Loc" = "居住地",
    "Sim" = "子女数量",
    "Edu_m" = "母亲学历",
    "Edu_f" = "父亲学历",
    "Age" = "年龄",
    "Exp" = "教龄",
    "Edu" = "学历",
    "Tit" = "职称"
)


########################################################
# 生成报告
########################################################
dist_list <- levels(dat_stu$区市)
# d <- "城阳区"

for (d in dist_list) {
   cat("正在生成", d, "的报告\n")
    # 获取区市的levels顺序
    qu_shi_levels <- levels(dat_stu$区市)
    # 创建映射：不等于d的区市按照levels顺序依次命名为B、C、D、E、F、G
    other_qu_shi <- setdiff(qu_shi_levels, d)
    letter_labels <- c("B", "C", "D", "E", "F", "G")[seq_along(other_qu_shi)]
    qu_shi_mapping <- setNames(letter_labels, other_qu_shi)
   
    dat_stu_all <- dat_stu %>% 
        mutate(区市 = case_when(
            # 如果区市等于d，保持原值不变
            区市 == d ~ as.character(区市),
            # 其他区市按照levels顺序依次命名为B、C、D、E、F、G
            区市 %in% names(qu_shi_mapping) ~ unname(qu_shi_mapping[as.character(区市)]),
            # 默认情况（应该不会出现，但为了安全）
            TRUE ~ as.character(区市)
        )) %>%
        mutate(区市 = factor(区市, levels = c(d, letter_labels)))
    dat_stu_d <- dat_stu %>% filter(区市 == d)

    dat_tea_all <- dat_tea %>% 
        mutate(区市 = case_when(
            # 如果区市等于d，保持原值不变
            区市 == d ~ as.character(区市),
            # 其他区市按照levels顺序依次命名为B、C、D、E、F、G（使用相同的映射）
            区市 %in% names(qu_shi_mapping) ~ unname(qu_shi_mapping[as.character(区市)]),
            # 默认情况（应该不会出现，但为了安全）
            TRUE ~ as.character(区市)
        )) %>%
        mutate(区市 = factor(区市, levels = c(d, letter_labels)))
    dat_tea_d <- dat_tea %>% filter(区市 == d)

    ########################################################
    # 创建文档和存储图表对象
    ########################################################
    # 创建新的文档（需要根据实际情况调整模板路径）
    doc <- read_docx("4 模板全部/doc_template_h_d.docx")
    
    # 存储图表对象
    chart_objects <- list()
    failed_charts <- data.frame(
        行号 = integer(),
        图表类型 = character(),
        报告维度 = character(),
        失败原因 = character(),
        stringsAsFactors = FALSE
    )
    
    # 获取日期字符串
    date_str <- format(Sys.Date(), "%Y%m%d")
    
    ########################################################
    # 添加目录和分页符
    ########################################################
    tryCatch({
        doc <- doc %>% officer::body_add_toc(level = 3)
        cat("已添加目录（包含1-3级标题）\n")
    }, error = function(e) {
        warning(paste("添加目录失败：", e$message))
    })
    
    doc <- doc %>% officer::body_add_break()
    cat("已添加分页符\n")
    
    ########################################################
    # 遍历index_report的每一行
    ########################################################
    for (i in seq_len(nrow(index_report))) {
        cat("正在生成:第", i, "行\n")
        row <- index_report[i, ]
        
        # 检查是否有效
        if ("是否有效" %in% colnames(index_report)) {
            valid_value <- row$是否有效
            if (is.na(valid_value)) {
                next
            } else if (is.logical(valid_value)) {
                if (!valid_value) next
            } else if (is.numeric(valid_value)) {
                if (valid_value != 1) next
            } else {
                valid_str <- as.character(valid_value)
                if (!valid_str %in% c("1", "是", "TRUE", "True", "true")) {
                    next
                }
            }
        }
        
        # 写入标题
        if (!is.na(row$一级标题) && row$一级标题 != "") {
            doc <- doc %>% body_add_par(row$一级标题, style = "一级标题")
        }
        if (!is.na(row$二级标题) && row$二级标题 != "") {
            doc <- doc %>% body_add_par(row$二级标题, style = "heading 2")
        }
        if (!is.na(row$三级标题) && row$三级标题 != "") {
            doc <- doc %>% body_add_par(row$三级标题, style = "heading 3")
        }
        if (!is.na(row$四级标题) && row$四级标题 != "") {
            doc <- doc %>% body_add_par(row$四级标题, style = "heading 4")
        }
        if (!is.na(row$五级标题) && row$五级标题 != "") {
            doc <- doc %>% body_add_par(row$五级标题, style = "heading 5")
        }
        
        # 写入文本段落（如果有）
        if (!is.na(row$文本段落) && row$文本段落 != "") {
            if (grepl("^注：", row$文本段落)) {
                doc <- doc %>% body_add_par(row$文本段落, style = "footer")
            } else {
                doc <- doc %>% body_add_par(row$文本段落, style = "Body Text")
            }
        }
        
        # 写入分页符
        if (!is.na(row$分页符) && (row$分页符 == "是" || row$分页符 == "1" || row$分页符 == 1)) {
            doc <- doc %>% body_add_break()
        }
        
        # 写入线下图表（如果有）
        if (!is.na(row$线下图表) && row$线下图表 != "") {
            if (row$报告学段 == "高中") {
                file_path <- file.path("9 pics and tables/1 h", row$线下图表)
            } else if (row$报告学段 == "中职") {
                file_path <- file.path("9 pics and tables/2 c", row$线下图表)
            } else {
                warning(paste("第", i, "行：报告学段为空"))
                next
            }
            
            if (file.exists(file_path)) {
                file_ext <- tolower(tools::file_ext(file_path))
                if (file_ext == "png") {
                    tryCatch({
                        file_size_mb <- file.info(file_path)$size / (1024 * 1024)
                        if (file_size_mb > 5) {
                            doc <- doc %>% body_add_img(file_path, width = 6, height = 4.5)
                        } else {
                            img_array <- png::readPNG(file_path, native = TRUE)
                            img_dims <- dim(img_array)
                            if (!is.null(img_dims) && length(img_dims) >= 2) {
                                aspect_ratio <- img_dims[1] / img_dims[2]
                                doc <- doc %>% body_add_img(file_path, width = 6, height = 6 * aspect_ratio)
                            } else {
                                doc <- doc %>% body_add_img(file_path, width = 6, height = 4.5)
                            }
                        }
                        doc <- doc %>% officer::body_add_par("")
                    }, error = function(e) {
                        warning(paste("第", i, "行：读取图片失败：", e$message))
                    })
                } else if (file_ext %in% c("xlsx", "csv")) {
                    # 处理表格文件（参考write_report_to_doc的完整逻辑）
                    tryCatch({
                        if (file_ext == "xlsx") {
                            table_data <- openxlsx::read.xlsx(file_path)
                        } else {
                            table_data <- read.csv(file_path, fileEncoding = "UTF-8", stringsAsFactors = FALSE)
                        }
                        
                        if ("图题表题" %in% colnames(row) && !is.na(row$图题表题) && row$图题表题 != "") {
                            doc <- doc %>% officer::body_add_par(row$图题表题, style = "图表标题")
                        }
                        
                        # 保存原始列名（用于后续处理）
                        original_colnames <- colnames(table_data)
                        
                        if (requireNamespace("flextable", quietly = TRUE)) {
                            # 保持原始列名创建flextable（避免重复列名错误）
                            ft <- flextable::flextable(table_data)
                            
                            # 列名为"分类"、"类别"、"指标"、"变化趋势"或"测量内容"（可能带".1"后缀）的列纵向合并单元格
                            category_cols <- grep("^(分类|类别|指标|变化趋势|测量内容|变量类型|评估工具)(\\.1)?$", colnames(table_data), value = FALSE)
                            for (category_col_idx in category_cols) {
                                if (!is.na(category_col_idx) && nrow(table_data) > 1) {
                                    category_col_name <- colnames(table_data)[category_col_idx]
                                    current_category <- ""
                                    start_row_cat <- 1
                                    
                                    for (r in seq_len(nrow(table_data))) {
                                        cell_value <- as.character(table_data[[category_col_name]][r])
                                        if (is.na(cell_value)) cell_value <- ""
                                        
                                        if (cell_value != current_category) {
                                            if (current_category != "" && r > start_row_cat) {
                                                # 只有多行相同值时才合并
                                                ft <- flextable::merge_at(ft, i = start_row_cat:(r-1), j = category_col_idx)
                                            }
                                            current_category <- cell_value
                                            start_row_cat <- r
                                        }
                                    }
                                    # 合并最后一批（只有多行相同值时才合并）
                                    if (start_row_cat < nrow(table_data)) {
                                        ft <- flextable::merge_at(ft, i = start_row_cat:nrow(table_data), j = category_col_idx)
                                    }
                                }
                            }
                            
                            # 最后一步：修改列名显示，去掉".1"后缀
                            header_labels <- as.list(original_colnames)
                            names(header_labels) <- original_colnames
                            for (col_name in original_colnames) {
                                if (grepl("\\.1$", col_name)) {
                                    base_name <- gsub("\\.1$", "", col_name)
                                    if (base_name %in% original_colnames) {
                                        header_labels[[col_name]] <- base_name
                                    }
                                }
                            }
                            ft <- flextable::set_header_labels(ft, values = header_labels)
                            
                            doc <- add_table_to_doc(doc, ft, table_style = "Normal Table", use_autofit = TRUE)
                        } else {
                            doc <- doc %>% body_add_table(table_data, style = "Normal Table")
                            doc <- doc %>% officer::body_add_par("")
                        }
                    }, error = function(e) {
                        warning(paste("第", i, "行：读取线下表格失败：", e$message))
                    })
                }
            }
        }
        
        # 生成图表
        if (!is.na(row$图表类型) && row$图表类型 != "") {
            chart_type <- trimws(row$图表类型)
            
            # 特殊处理：text_psy_tea_cnt类型，只生成文本，不生成图表
            if (chart_type == "text_psy_tea_cnt") {
                # 使用区级教师数据
                if (!is.na(row$数据表对应) && row$数据表对应 == "tea") {
                    dat_for_text <- dat_tea_d
                } else {
                    dat_for_text <- dat_tea_d  # 默认使用教师数据
                }
                
                # 生成文本
                text_obj <- tryCatch({
                    generate_chart(dat_for_text, row, index_item, i, color_palette, figures_with_dot, 
                                 hide_other_labels = TRUE, target_district = d,
                                 table_cnt_stu_left_vars = table_cnt_stu_left_vars,
                                 table_cnt_stu_right_vars = table_cnt_stu_right_vars,
                                 table_cnt_tea_left_vars = table_cnt_tea_left_vars,
                                 table_cnt_tea_right_vars = table_cnt_tea_right_vars,
                                 var_name_mapping = var_name_mapping)
                }, error = function(e) {
                    failed_charts <<- rbind(failed_charts, data.frame(
                        行号 = i,
                        图表类型 = ifelse(is.na(row$图表类型), "", as.character(row$图表类型)),
                        报告维度 = ifelse(is.na(row$报告维度), "", as.character(row$报告维度)),
                        失败原因 = paste("生成失败：", e$message),
                        stringsAsFactors = FALSE
                    ))
                    NULL
                })
                
                # 如果成功生成文本，写入文档
                if (!is.null(text_obj) && !is.null(text_obj$text)) {
                    doc <- doc %>% body_add_par(text_obj$text, style = "Body Text")
                }
                next  # 跳过后续的图表处理
            }
            
            # 根据函数类型选择数据源
            if (chart_type %in% use_dist_funs) {
                # 使用区级数据
                if (!is.na(row$数据表对应) && row$数据表对应 == "tea") {
                    dat_for_chart <- dat_tea_d
                } else {
                    dat_for_chart <- dat_stu_d
                }
            } else {
                # 使用总体数据（区市已转换）
                if (!is.na(row$数据表对应) && row$数据表对应 == "tea") {
                    dat_for_chart <- dat_tea_all
                } else {
                    dat_for_chart <- dat_stu_all
                }
            }
            
            # 生成图表
            chart_obj <- tryCatch({
                generate_chart(dat_for_chart, row, index_item, i, color_palette, figures_with_dot, 
                               hide_other_labels = TRUE, target_district = d,
                               table_cnt_stu_left_vars = table_cnt_stu_left_vars,
                               table_cnt_stu_right_vars = table_cnt_stu_right_vars,
                               table_cnt_tea_left_vars = table_cnt_tea_left_vars,
                               table_cnt_tea_right_vars = table_cnt_tea_right_vars,
                               var_name_mapping = var_name_mapping,
                               return_text_for_table_cnt_stu = TRUE)
            }, error = function(e) {
                failed_charts <<- rbind(failed_charts, data.frame(
                    行号 = i,
                    图表类型 = ifelse(is.na(row$图表类型), "", as.character(row$图表类型)),
                    报告维度 = ifelse(is.na(row$报告维度), "", as.character(row$报告维度)),
                    失败原因 = paste("生成失败：", e$message),
                    stringsAsFactors = FALSE
                ))
                NULL
            })
            
            if (!is.null(chart_obj)) {
                # 处理table_cnt_stu返回的文本（如果存在）
                if (chart_type == "table_cnt_stu" && is.list(chart_obj) && !is.null(chart_obj$text)) {
                    doc <- doc %>% body_add_par(chart_obj$text, style = "Body Text")
                    # 将chart_obj设置为table，以便后续处理表格
                    chart_obj <- chart_obj$table
                }
                
                chart_objects[[paste0("chart_", i)]] <- chart_obj
                
                # 如果需要添加动态文本
                if (chart_type %in% text_need_funs) {
                    text_paragraph <- tryCatch({
                        generate_text_for_chart(chart_obj, chart_type, row, d, dat_for_chart, figures_with_dot, index_item)
                    }, error = function(e) {
                        warning(paste("第", i, "行：生成文本失败：", e$message))
                        NULL
                    })
                    
                    if (!is.null(text_paragraph) && text_paragraph != "") {
                        doc <- doc %>% body_add_par(text_paragraph, style = "Body Text")
                    }
                }
                
                # 写入图表
                # 如果是表格
                if (is.data.frame(chart_obj) || (!is.null(chart_obj$table) && is.null(chart_obj$plot))) {
                    tables_to_add <- list()
                    if (is.data.frame(chart_obj)) {
                        tables_to_add <- list(chart_obj)
                    } else if (!is.null(chart_obj$tables) && is.list(chart_obj$tables)) {
                        tables_to_add <- chart_obj$tables
                    } else if (!is.null(chart_obj$table)) {
                        tables_to_add <- list(chart_obj$table)
                    }
                    
                    for (table_idx in seq_along(tables_to_add)) {
                        table_to_add <- tables_to_add[[table_idx]]
                        if (is.null(table_to_add) || nrow(table_to_add) == 0) next
                        
                        if (table_idx == 1 && !is.na(row$图题表题) && row$图题表题 != "") {
                            doc <- doc %>% officer::body_add_par(row$图题表题, style = "图表标题")
                        }
                        
                        # 如果是Cronbach_alpha，确保题目数量显示为整数
                        if (row$图表类型 == "Cronbach_alpha" && "参数" %in% colnames(table_to_add)) {
                            # 找到"题目数量"行，将该行的所有数值列转换为整数格式的字符串
                            item_count_row <- which(table_to_add$参数 == "题目数量")
                            if (length(item_count_row) > 0) {
                                for (col_idx in 2:ncol(table_to_add)) {
                                    if (is.numeric(table_to_add[item_count_row, col_idx])) {
                                        # 先转换为整数，再转换为字符串，确保Word中显示为整数
                                        int_value <- as.integer(round(table_to_add[item_count_row, col_idx]))
                                        table_to_add[item_count_row, col_idx] <- as.character(int_value)
                                    }
                                }
                            }
                        }
                        
                        # 如果是table_items_score，确保维度均分行在最后，并格式化平均分列
                        if (row$图表类型 == "table_items_score" && "题目" %in% colnames(table_to_add) && "平均分" %in% colnames(table_to_add)) {
                            # 确保"维度均分"行在最后
                            dim_mean_row <- which(table_to_add$题目 == "维度均分")
                            if (length(dim_mean_row) > 0) {
                                # 如果维度均分行不在最后，将其移到最后
                                if (dim_mean_row[1] != nrow(table_to_add)) {
                                    other_rows <- table_to_add[-dim_mean_row, ]
                                    dim_mean_row_data <- table_to_add[dim_mean_row, ]
                                    table_to_add <- rbind(other_rows, dim_mean_row_data)
                                }
                            }
                            # 格式化平均分列：保留2位小数
                            if (is.numeric(table_to_add$平均分)) {
                                table_to_add$平均分 <- round(table_to_add$平均分, 2)
                            }
                        }
                        
                        # 保存原始列名（用于后续处理）
                        original_colnames <- colnames(table_to_add)
                        
                        if (requireNamespace("flextable", quietly = TRUE)) {
                            # 保持原始列名创建flextable（避免重复列名错误）
                            ft <- flextable::flextable(table_to_add)
                            
                            # 检查是否为左右两列格式（是否有"分类.1"列）
                            has_left_right_format <- "分类.1" %in% colnames(table_to_add)
                            
                            if (has_left_right_format) {
                                # 左右两列格式：分别处理左侧和右侧的分类合并，并添加底部边框
                                max_rows <- nrow(table_to_add)
                                
                                # 合并左侧相同分类的单元格（第1列：分类）
                                current_class_left <- ""
                                start_row_left <- 1
                                left_group_end_rows <- c()  # 记录左侧每个分类组的结束行
                                for (r in seq_len(max_rows)) {
                                    cell_value <- as.character(table_to_add$分类[r])
                                    if (is.na(cell_value)) cell_value <- ""
                                    if (cell_value != "" && cell_value != current_class_left) {
                                        if (current_class_left != "" && r > start_row_left) {
                                            ft <- flextable::merge_at(ft, i = start_row_left:(r-1), j = 1)
                                            left_group_end_rows <- c(left_group_end_rows, r - 1)
                                        }
                                        current_class_left <- cell_value
                                        start_row_left <- r
                                    }
                                }
                                # 合并最后一批左侧分类
                                if (current_class_left != "" && start_row_left <= max_rows) {
                                    end_row <- start_row_left
                                    for (r in start_row_left:max_rows) {
                                        cell_value <- as.character(table_to_add$分类[r])
                                        if (is.na(cell_value)) cell_value <- ""
                                        if (cell_value == current_class_left) {
                                            end_row <- r
                                        } else {
                                            break
                                        }
                                    }
                                    if (end_row > start_row_left) {
                                        ft <- flextable::merge_at(ft, i = start_row_left:end_row, j = 1)
                                        if (end_row < max_rows) {
                                            left_group_end_rows <- c(left_group_end_rows, end_row)
                                        }
                                    }
                                }
                                
                                # 合并右侧相同分类的单元格
                                # 计算右侧分类列的索引：找到"分类.1"列的索引
                                right_class_col <- which(colnames(table_to_add) == "分类.1")
                                if (length(right_class_col) > 0) {
                                    right_class_col <- right_class_col[1]
                                    current_class_right <- ""
                                    start_row_right <- 1
                                    right_group_end_rows <- c()  # 记录右侧每个分类组的结束行
                                    for (r in seq_len(max_rows)) {
                                        cell_value <- as.character(table_to_add$分类.1[r])
                                        if (is.na(cell_value)) cell_value <- ""
                                        if (cell_value != "" && cell_value != current_class_right) {
                                            if (current_class_right != "" && r > start_row_right) {
                                                ft <- flextable::merge_at(ft, i = start_row_right:(r-1), j = right_class_col)
                                                right_group_end_rows <- c(right_group_end_rows, r - 1)
                                            }
                                            current_class_right <- cell_value
                                            start_row_right <- r
                                        }
                                    }
                                    # 合并最后一批右侧分类
                                    if (current_class_right != "" && start_row_right <= max_rows) {
                                        end_row <- start_row_right
                                        for (r in start_row_right:max_rows) {
                                            cell_value <- as.character(table_to_add$分类.1[r])
                                            if (is.na(cell_value)) cell_value <- ""
                                            if (cell_value == current_class_right) {
                                                end_row <- r
                                            } else {
                                                break
                                            }
                                        }
                                        if (end_row > start_row_right) {
                                            ft <- flextable::merge_at(ft, i = start_row_right:end_row, j = right_class_col)
                                            if (end_row < max_rows) {
                                                right_group_end_rows <- c(right_group_end_rows, end_row)
                                            }
                                        }
                                    }
                                }
                                
                                # 为左侧和右侧每个分类组的最后一行添加底部边框（横线）
                                all_group_end_rows <- unique(c(left_group_end_rows, right_group_end_rows))
                                if (length(all_group_end_rows) > 0) {
                                    for (end_row in all_group_end_rows) {
                                        if (end_row < max_rows) {
                                            n_cols <- length(colnames(table_to_add))
                                            ft <- flextable::border(ft, 
                                                                   i = end_row, 
                                                                   j = seq_len(n_cols),
                                                                   border.bottom = officer::fp_border(color = "black", width = 1),
                                                                   part = "body")
                                        }
                                    }
                                }
                            } else {
                                # 单列格式：使用原来的逻辑
                                category_cols <- grep("^(分类|类别|指标|变化趋势|测量内容|变量类型|评估工具)(\\.1)?$", colnames(table_to_add), value = FALSE)
                                for (category_col_idx in category_cols) {
                                    if (!is.na(category_col_idx) && nrow(table_to_add) > 1) {
                                        category_col_name <- colnames(table_to_add)[category_col_idx]
                                        current_category <- ""
                                        start_row_cat <- 1
                                        
                                        for (r in seq_len(nrow(table_to_add))) {
                                            cell_value <- as.character(table_to_add[[category_col_name]][r])
                                            if (is.na(cell_value)) cell_value <- ""
                                            
                                            if (cell_value != current_category) {
                                                if (current_category != "" && r > start_row_cat) {
                                                    # 只有多行相同值时才合并
                                                    ft <- flextable::merge_at(ft, i = start_row_cat:(r-1), j = category_col_idx)
                                                }
                                                current_category <- cell_value
                                                start_row_cat <- r
                                            }
                                        }
                                        # 合并最后一批（只有多行相同值时才合并）
                                        if (start_row_cat < nrow(table_to_add)) {
                                            ft <- flextable::merge_at(ft, i = start_row_cat:nrow(table_to_add), j = category_col_idx)
                                        }
                                    }
                                }
                            }
                            
                            # 最后一步：修改列名显示，去掉".1"后缀
                            header_labels <- as.list(original_colnames)
                            names(header_labels) <- original_colnames
                            for (col_name in original_colnames) {
                                if (grepl("\\.1$", col_name)) {
                                    base_name <- gsub("\\.1$", "", col_name)
                                    if (base_name %in% original_colnames) {
                                        header_labels[[col_name]] <- base_name
                                    }
                                }
                            }
                            ft <- flextable::set_header_labels(ft, values = header_labels)
                            
                            # 设置所有单元格居中（包括表头和主体）
                            ft <- ft %>% flextable::align(align = "center", part = "header") %>%
                                        flextable::align(align = "center", part = "body")
                            
                            # 列名包含"变量"或"题目"的列设置为居左对齐
                            col_names <- colnames(table_to_add)
                            left_align_cols <- which(grepl("变量|题目", col_names))
                            if (length(left_align_cols) > 0) {
                                ft <- ft %>% flextable::align(align = "left", j = left_align_cols, part = "header") %>%
                                            flextable::align(align = "left", j = left_align_cols, part = "body")
                            }
                            
                            doc <- add_table_to_doc(doc, ft, table_style = "Normal Table", use_autofit = TRUE)
                        } else {
                            doc <- doc %>% body_add_table(table_to_add, style = "Normal Table")
                            doc <- doc %>% officer::body_add_par("")
                        }
                    }
                }
                
                # 如果是图片
                if (!is.null(chart_obj$plot) || inherits(chart_obj, "ggplot")) {
                    tryCatch({
                        # 保存临时图片
                        temp_file <- tempfile(fileext = ".png")
                        
                        # 确定图片高度
                        plot_height <- 4  # 默认高度
                        if (!is.null(chart_obj$plot)) {
                            if (inherits(chart_obj$plot, "gtable")) {
                                # 如果是arrangeGrob的结果（合并的图片）
                                gtable_obj <- chart_obj$plot
                                layout_rows <- unique(gtable_obj$layout$t)
                                layout_cols <- unique(gtable_obj$layout$l)
                                n_rows_est <- length(layout_rows)
                                n_cols_est <- length(layout_cols)
                                
                                single_width <- 5.5
                                single_height <- 1.8
                                title_space <- ifelse(n_rows_est >= 2, 0.3, 0.2)
                                plot_height <- n_rows_est * single_height + title_space
                                plot_width <- n_cols_est * single_width
                                
                                if (plot_height > 7) plot_height <- 7
                                
                                img_width <- round(plot_width * 300)
                                img_height <- round(plot_height * 300)
                                
                                png(temp_file, width = img_width, height = img_height, res = 300)
                                grid.draw(chart_obj$plot)
                                dev.off()
                            } else if (inherits(chart_obj$plot, "patchwork")) {
                                # 如果是patchwork的结果
                                patchwork_obj <- chart_obj$plot
                                n_rows_est <- NULL
                                n_cols_est <- NULL
                                if (!is.null(patchwork_obj$patches) && !is.null(patchwork_obj$patches$layout)) {
                                    layout <- patchwork_obj$patches$layout
                                    if (!is.null(layout$nrow)) n_rows_est <- layout$nrow
                                    if (!is.null(layout$ncol)) n_cols_est <- layout$ncol
                                }
                                
                                if (is.null(n_rows_est) || is.null(n_cols_est)) {
                                    chart_type <- row$图表类型
                                    if (grepl("difference_class", chart_type)) {
                                        n_cols_est <- 2
                                        n_rows_est <- 2
                                    } else {
                                        n_cols_est <- 2
                                        n_rows_est <- 1
                                    }
                                }
                                
                                single_width <- 5.5
                                single_height <- 1.8
                                title_space <- ifelse(n_rows_est >= 2, 0.3, 0.2)
                                plot_height <- n_rows_est * single_height + title_space
                                plot_width <- n_cols_est * single_width
                                
                                if (plot_height > 7) plot_height <- 7
                                
                                ggsave(temp_file, patchwork_obj, width = plot_width, height = plot_height, dpi = 300)
                            } else {
                                # 检查是否有存储的高度信息
                                if (!is.null(attr(chart_obj$plot, "plot_height"))) {
                                    plot_height <- attr(chart_obj$plot, "plot_height")
                                } else {
                                    chart_type <- row$图表类型
                                    if (chart_type == "simple_bar_dis_figures") {
                                        plot_height <- 3
                                    } else if (chart_type == "simple_bar_subdim_figures" || chart_type == "simple_bar_subdim_score") {
                                        plot_height <- 2.5
                                    } else if (grepl("difference_class", chart_type)) {
                                        plot_height <- 3
                                    } else if (chart_type == "pie_distribution") {
                                        plot_height <- 3.2
                                    }
                                }
                                ggsave(temp_file, chart_obj$plot, width = 5.5, height = plot_height, dpi = 300)
                            }
                        } else if (inherits(chart_obj, "ggplot")) {
                            ggsave(temp_file, chart_obj, width = 5.5, height = plot_height, dpi = 300)
                        }
                        
                        if (file.exists(temp_file)) {
                            # 图片的标题已经在图中了，不需要再写入"图题表题"
                            doc <- doc %>% body_add_img(temp_file, width = 5.5, height = plot_height)
                            doc <- doc %>% officer::body_add_par("")
                        }
                    }, error = function(e) {
                        warning(paste("第", i, "行：写入图片失败：", e$message))
                    })
                }
            }
        }
    }
    
    ########################################################
    # 保存文档
    ########################################################
    output_dir <- "10 过程报告/1 h dist"
    dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
    output_path <- file.path(output_dir, paste0(date_str, "版本_区级报告_", d, ".docx"))
    print(doc, target = output_path)
    cat("已保存报告至：", output_path, "\n")
    
    # 保存失败图表信息
    if (nrow(failed_charts) > 0) {
        failed_path <- file.path(output_dir, paste0(date_str, "版本_区级失败图表_", d, ".csv"))
        write.csv(failed_charts, failed_path, row.names = FALSE, fileEncoding = "UTF-8")
        cat("已保存失败图表信息至：", failed_path, "\n")
    }
    cat("完成", d, "的报告\n")

}
