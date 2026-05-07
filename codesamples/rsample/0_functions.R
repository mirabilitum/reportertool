# 函数库依赖
library(dplyr)

########################################################
# 路径辅助函数
########################################################

# 根据报告学段返回表格保存路径
get_table_path <- function(index_report_row) {
    if ("报告学段" %in% colnames(index_report_row) && !is.na(index_report_row$报告学段)) {
        if (index_report_row$报告学段 == "中职") {
            return("11 tables_for_plot/2 c")
        } else if (index_report_row$报告学段 == "高中") {
            return("11 tables_for_plot/1 h")
        } else if (index_report_row$报告学段 == "初中") {
            return("11 tables_for_plot/3 jh")
        }

    }
    # 默认路径（如果没有报告学段或值不匹配）
    return("11 tables_for_plot")
}

########################################################
# 颜色映射辅助函数
########################################################

# 根据类别生成颜色映射，特殊处理"达标"和"不达标"
# reverse: 是否反转颜色顺序（默认FALSE，对于pie_distribution和difference_class使用TRUE）
get_color_mapping <- function(categories, color_palette, reverse = FALSE) {
    n_categories <- length(categories)
    
    # 检查是否有"达标"和"不达标"
    has_dabiao <- "达标" %in% categories
    has_budabiao <- "不达标" %in% categories
    
    # 检查是否有"表现好"、"表现较好"、"表现待提高"
    has_biaoxianhao <- "表现好" %in% categories
    has_biaoxianjiaohao <- "表现较好" %in% categories
    has_biaoxiandaiditi <- "表现待提高" %in% categories
    
    # 根据类别数量选择基础颜色
    color_key <- paste0("color_", n_categories)
    if (color_key %in% names(color_palette)) {
        base_colors <- color_palette[[color_key]]
    } else if (n_categories <= length(color_palette$color_9)) {
        base_colors <- color_palette$color_9[1:n_categories]
    } else if ("color_11" %in% names(color_palette) && n_categories <= length(color_palette$color_11)) {
        base_colors <- color_palette$color_11[1:n_categories]
    } else {
        base_colors <- rep(color_palette$color_1[1], n_categories)
    }
    
    # 如果需要反转颜色顺序，先反转基础颜色
    if (reverse) {
        base_colors <- rev(base_colors)
    }
    
    # 创建颜色映射
    color_mapping <- setNames(base_colors, categories)
    
    # 特殊处理"达标"和"不达标"（在反转后恢复它们的颜色）
    if (has_dabiao && "color_2_evaluation" %in% names(color_palette)) {
        color_mapping["达标"] <- color_palette$color_2_evaluation[1]
    }
    if (has_budabiao && "color_2_evaluation" %in% names(color_palette)) {
        color_mapping["不达标"] <- color_palette$color_2_evaluation[2]
    }
    
    # 特殊处理"表现好"、"表现较好"、"表现待提高"
    if (has_biaoxianhao) {
        color_mapping["表现好"] <- "#60778A"
    }
    if (has_biaoxianjiaohao) {
        color_mapping["表现较好"] <- "#BFAF6D"
    }
    if (has_biaoxiandaiditi) {
        color_mapping["表现待提高"] <- "#A86D70"
    }
    
    return(color_mapping)
}

# 根据index_report_row$数据表对应来过滤index_item
# 返回过滤后的index_item数据框
filter_index_item_by_data_table <- function(index_item, index_report_row) {
    # 获取数据表对应信息
    data_table <- index_report_row$数据表对应
    if (is.na(data_table) || data_table == "") {
        # 如果没有指定，返回原始index_item
        return(index_item)
    }
    
    # 根据数据表对应来过滤
    if (data_table == "tea") {
        # 教师问卷
        if ("数据表名" %in% colnames(index_item)) {
            return(index_item %>% filter(数据表名 == "教师问卷"))
        } else {
            return(index_item)
        }
    } else if (data_table == "stu_par") {
        # 学生问卷或家长问卷
        if ("数据表名" %in% colnames(index_item)) {
            return(index_item %>% filter(数据表名 %in% c("学生问卷", "家长问卷")))
        } else {
            return(index_item)
        }
    } else {
        # 其他情况，返回原始index_item
        return(index_item)
    }
}




########################################################
# 数据计算相关函数
########################################################

# Cal_MEAN：【_Score】计算该维度题目均分；
# 逻辑：index_h中，对于算法【MEAN】的行：
# 每一个【报告维度】dim对应的【题目列名】是该维度需要计算均值的dat_stu_h中的列名。计算均值后，将结果赋值给dat_stu_h中paste0(dim,"_Score")列。
# 计算时，na.rm = TRUE。
Cal_MEAN <- function(dat, index, 
                     algorithm_col = "算法",
                     dim_col = "报告维度",
                     item_col = "题目列名") {
    # 筛选出算法包含MEAN的行（算法列用//C//分割）
    mean_rows <- index %>%
        filter(!is.na(.data[[algorithm_col]])) %>%
        rowwise() %>%
        filter({
            algos <- strsplit(.data[[algorithm_col]], "//C//", fixed = TRUE)[[1]]
            "MEAN" %in% trimws(algos)
        }) %>%
        ungroup()
    
    # 按报告维度分组处理
    dim_list <- unique(mean_rows[[dim_col]])
    dim_list <- dim_list[!is.na(dim_list)]
    
    for (dim in dim_list) {
        # 获取该维度对应的所有题目列名
        items <- mean_rows %>%
            filter(.data[[dim_col]] == dim) %>%
            pull(.data[[item_col]])
        items <- items[!is.na(items)]
        
        # 检查这些列是否存在于dat中
        existing_items <- items[items %in% colnames(dat)]
        
        if (length(existing_items) == 1) {
            # 如果只有一列，直接等于这一列
            score_col <- paste0(dim, "_Score")
            dat[[score_col]] <- as.numeric(as.character(dat[[existing_items[1]]]))
        } else if (length(existing_items) > 1) {
            # 计算均值（先将列转换为数值型）
            score_col <- paste0(dim, "_Score")
            dat_subset <- dat[, existing_items, drop = FALSE]
            # 将所有列转换为数值型
            dat_subset <- as.data.frame(lapply(dat_subset, function(x) as.numeric(as.character(x))))
            dat[[score_col]] <- rowMeans(dat_subset, na.rm = TRUE)
        } else {
            warning(paste("维度", dim, "的题目列在dat中不存在"))
        }
    }
    
    return(dat)
}


# Cal_SUM：【_Score】计算该维度题目总分；
# 逻辑：index_h中，对于算法【SUM】的行：
# 每一个【报告维度】dim对应的【题目列名】是该维度需要计算总分的dat_stu_h中的列名。计算总分后，将结果赋值给dat_stu_h中paste0(dim,"_Score")列。
# 计算时，na.rm = TRUE。
Cal_SUM <- function(dat, index,
                    algorithm_col = "算法",
                    dim_col = "报告维度",
                    item_col = "题目列名") {
    # 筛选出算法包含SUM的行（算法列用//C//分割）
    # 例如：SUM//C//ClassThreshold（5、10、15）//C//FigureClass（重度焦虑风险）
    # 分割后会得到：["SUM", "ClassThreshold（5、10、15）", "FigureClass（重度焦虑风险）"]
    # 然后用"SUM" %in% trimws(algos)检查是否包含SUM
    sum_rows <- index %>%
        filter(!is.na(.data[[algorithm_col]])) %>%
        rowwise() %>%
        filter({
            algos <- strsplit(.data[[algorithm_col]], "//C//", fixed = TRUE)[[1]]
            "SUM" %in% trimws(algos)
        }) %>%
        ungroup()
    
    # 按报告维度分组处理
    dim_list <- unique(sum_rows[[dim_col]])
    dim_list <- dim_list[!is.na(dim_list)]
    
    for (dim in dim_list) {
        # 获取该维度对应的所有题目列名
        items <- sum_rows %>%
            filter(.data[[dim_col]] == dim) %>%
            pull(.data[[item_col]])
        items <- items[!is.na(items)]
        
        # 检查这些列是否存在于dat中
        existing_items <- items[items %in% colnames(dat)]
        
        if (length(existing_items) > 0) {
            # 计算总分（先将列转换为数值型）
            score_col <- paste0(dim, "_Score")
            dat_subset <- dat[, existing_items, drop = FALSE]
            # 将所有列转换为数值型
            dat_subset <- as.data.frame(lapply(dat_subset, function(x) as.numeric(as.character(x))))
            
            # 检查是否存在"用户提交时间_学生"列
            student_time_col <- "用户提交时间_学生"
            if (student_time_col %in% colnames(dat)) {
                # 如果"用户提交时间_学生"列为空，则Score也应为空
                dat[[score_col]] <- ifelse(is.na(dat[[student_time_col]]), 
                                          NA, 
                                          rowSums(dat_subset, na.rm = TRUE))
            } else {
                # 如果不存在该列，使用原来的逻辑
                dat[[score_col]] <- rowSums(dat_subset, na.rm = TRUE)
            }
        } else {
            warning(paste("维度", dim, "的题目列在dat中不存在"))
        }
    }
    
    return(dat)
}


# Cal_ClassChoice（1、2）：【_Class】选择这些选项的，class为【报告维度分类名1】、选择其他的class为【报告维度分类名2】
# 逻辑：index_h中，对于算法【ClassChoice】的行：
# 从算法括号内识别选项序号（如1、2），然后从index$选项列中按序号获取选项内容（用//C//分割）
# 判断dat_stu_h中，每一个【报告维度】dim对应的【题目列名】中，值是否在这些选项内容中
# 如果是，则将dat_stu_h中paste0(dim,"_Class")列赋值为【报告维度分类名1】，否则赋值为【报告维度分类名2】。
# 如果是空，仍为空
Cal_ClassChoice <- function(dat, index,
                            algorithm_col = "算法",
                            dim_col = "报告维度",
                            item_col = "题目列名",
                            option_col = "选项",
                            class_name1_col = "报告维度分类名1",
                            class_name2_col = "报告维度分类名2") {
    # 筛选出算法包含ClassChoice的行（算法列用//C//分割）
    choice_rows <- index %>%
        filter(!is.na(.data[[algorithm_col]])) %>%
        rowwise() %>%
        filter({
            algos <- strsplit(.data[[algorithm_col]], "//C//", fixed = TRUE)[[1]]
            any(grepl("ClassChoice", trimws(algos)))
        }) %>%
        ungroup()
    
    # 按报告维度分组处理
    dim_list <- unique(choice_rows[[dim_col]])
    dim_list <- dim_list[!is.na(dim_list)]
    
    for (dim in dim_list) {
        # 获取该维度对应的行
        dim_rows <- choice_rows %>%
            filter(.data[[dim_col]] == dim)
        
        if (nrow(dim_rows) == 0) next
        
        # 获取题目列名
        item <- dim_rows[[item_col]][1]
        if (is.na(item) || !item %in% colnames(dat)) {
            warning(paste("维度", dim, "的题目列", item, "在dat中不存在"))
            next
        }
        
        # 从算法中提取选项序号（中文括号内的内容）
        # 算法列可能包含多个算法（用//C//分割），需要找到包含ClassChoice的部分
        algorithm_full <- dim_rows[[algorithm_col]][1]
        algos_split <- strsplit(algorithm_full, "//C//", fixed = TRUE)[[1]]
        algorithm_str <- algos_split[grepl("ClassChoice", algos_split)][1]
        if (is.na(algorithm_str)) {
            warning(paste("无法从算法中找到ClassChoice：", algorithm_full))
            next
        }
        algorithm_str <- trimws(algorithm_str)
        # 匹配中文括号内的内容，例如 "ClassChoice（1、2）"
        match_result <- regmatches(algorithm_str, regexpr("（[^）]+）", algorithm_str))
        if (length(match_result) > 0) {
            # 提取括号内的内容，去掉括号
            choices_str <- gsub("（|）", "", match_result)
            # 分割选项序号（支持顿号、逗号、空格等分隔符）
            choice_indices <- strsplit(choices_str, "[、，, ]+")[[1]]
            # 转换为数值型（选项序号，从1开始）
            choice_indices <- as.numeric(choice_indices)
            choice_indices <- choice_indices[!is.na(choice_indices)]
        } else {
            warning(paste("无法从算法提取选项序号：", algorithm_str))
            next
        }
        
        # 从选项列中获取选项内容
        option_str <- dim_rows[[option_col]][1]
        if (is.na(option_str) || option_str == "") {
            warning(paste("维度", dim, "的选项列为空"))
            next
        }
        
        # 用//C//分割选项
        option_list <- strsplit(option_str, "//C//", fixed = TRUE)[[1]]
        option_list <- trimws(option_list)  # 去除首尾空格
        
        # 根据序号获取对应的选项内容
        target_options <- character(0)
        for (idx in choice_indices) {
            if (idx >= 1 && idx <= length(option_list)) {
                target_options <- c(target_options, option_list[idx])
            } else {
                warning(paste("维度", dim, "的选项序号", idx, "超出范围（共", length(option_list), "个选项）"))
            }
        }
        
        if (length(target_options) == 0) {
            warning(paste("维度", dim, "无法获取有效的选项内容"))
            next
        }
        
        # 获取分类名
        class_name1 <- dim_rows[[class_name1_col]][1]
        class_name2 <- dim_rows[[class_name2_col]][1]
        
        # 判断题目值是否在目标选项内容中
        class_col <- paste0(dim, "_Class")
        dat[[class_col]] <- ifelse(
            is.na(dat[[item]]),
            NA_character_,
            ifelse(
                dat[[item]] %in% target_options,
                class_name1,
                class_name2
            )
        )
    }
    
    return(dat)
}


#  Cal_ClassThreshold（3.2）：【_Class】按_score划分为多类，1个值分2类，2个值分3类；由低到高赋值为【报告维度分类名1:N】
# 逻辑：index_h中，对于算法【ClassThreshold】的行：
# 先识别ClassThreshold后面中文括号内的数字，例如3.2，则表示1个值分2类，2个值分3类。
# 分类需要向上取，即<3.2的赋值为【报告维度分类名2】，>=3.2的赋值为【报告维度分类名2】。
# dim_list作为参数输入，对每个dim_list，你需要用paste0(dim,"_Score")列来进行上述划分。
Cal_ClassThreshold <- function(dat, index, dim_list,
                                algorithm_col = "算法",
                                dim_col = "报告维度",
                                class_name_col_prefix = "报告维度分类名") {
    # 筛选出算法包含ClassThreshold的行（算法列用//C//分割）
    threshold_rows <- index %>%
        filter(!is.na(.data[[algorithm_col]])) %>%
        rowwise() %>%
        filter({
            algos <- strsplit(.data[[algorithm_col]], "//C//", fixed = TRUE)[[1]]
            any(grepl("ClassThreshold", trimws(algos)))
        }) %>%
        ungroup()
    
    for (dim in dim_list) {
        # 获取该维度对应的行
        dim_rows <- threshold_rows %>%
            filter(.data[[dim_col]] == dim)
        
        if (nrow(dim_rows) == 0) {
            warning(paste("维度", dim, "在index中找不到ClassThreshold配置"))
            next
        }
        
        # 检查Score列是否存在
        score_col <- paste0(dim, "_Score")
        if (!score_col %in% colnames(dat)) {
            warning(paste("维度", dim, "的Score列", score_col, "不存在"))
            next
        }
        
        # 从算法中提取阈值（中文括号内的数字）
        # 算法列可能包含多个算法（用//C//分割），需要找到包含ClassThreshold的部分
        algorithm_full <- dim_rows[[algorithm_col]][1]
        algos_split <- strsplit(algorithm_full, "//C//", fixed = TRUE)[[1]]
        algorithm_str <- algos_split[grepl("ClassThreshold", algos_split)][1]
        if (is.na(algorithm_str)) {
            warning(paste("无法从算法中找到ClassThreshold：", algorithm_full))
            next
        }
        algorithm_str <- trimws(algorithm_str)
        # 匹配中文括号内的数字，例如 "ClassThreshold（3.2）"
        match_result <- regmatches(algorithm_str, regexpr("（[^）]+）", algorithm_str))
        if (length(match_result) > 0) {
            # 提取括号内的内容，去掉括号
            threshold_str <- gsub("（|）", "", match_result)
            # 提取数字（支持多个阈值，用顿号、逗号等分隔）
            thresholds <- as.numeric(strsplit(threshold_str, "[、，, ]+")[[1]])
            thresholds <- thresholds[!is.na(thresholds)]
            thresholds <- sort(thresholds)  # 排序
        } else {
            warning(paste("无法从算法提取阈值：", algorithm_str))
            next
        }
        
        # 确定分类数量：n个阈值分n+1类
        n_classes <- length(thresholds) + 1
        
        # 获取分类名（报告维度分类名1, 报告维度分类名2, ...）
        class_names <- character(n_classes)
        for (i in 1:n_classes) {
            class_name_col <- paste0(class_name_col_prefix, i)
            if (class_name_col %in% colnames(dim_rows)) {
                class_names[i] <- dim_rows[[class_name_col]][1]
            } else {
                class_names[i] <- paste0("类别", i)
            }
        }
        
        # 进行分类
        class_col <- paste0(dim, "_Class")
        dat[[class_col]] <- NA_character_
        
        # 从低到高分类
        for (i in 1:n_classes) {
            if (i == 1) {
                # 第一类：< 第一个阈值
                dat[[class_col]][!is.na(dat[[score_col]]) & dat[[score_col]] < thresholds[1]] <- class_names[i]
            } else if (i == n_classes) {
                # 最后一类：>= 最后一个阈值
                dat[[class_col]][!is.na(dat[[score_col]]) & dat[[score_col]] >= thresholds[length(thresholds)]] <- class_names[i]
            } else {
                # 中间类：>= 前一个阈值 且 < 当前阈值
                dat[[class_col]][!is.na(dat[[score_col]]) & 
                                 dat[[score_col]] >= thresholds[i-1] & 
                                 dat[[score_col]] < thresholds[i]] <- class_names[i]
            }
        }
    }
    
    return(dat)
}


# Cal_FigureClass（表现较好、表现好）：【_Figure】用class，统计学生是否在这些类别里，算指数时平均即可
# 逻辑：index_h中，对于算法【FigureClass】的行：
# 先识别ClassThreshold后面中文括号内的类别，顿号分割。
# 判断dat_stu_h中，每一个【报告维度】dim对应的paste0(dim,"_Class")中，是否存在表现较好和表现好的选项.
# （注意，表现较好和表现好是通过FigureClass后面的中文括号识别出来的，再index中，有很多不同的设置）。
# 如果是，则将dat_stu_h中paste0(dim,"_Figure")列赋值为1，否则赋值为0。
Cal_FigureClass <- function(dat, index,
                             algorithm_col = "算法",
                             dim_col = "报告维度") {
    # 筛选出算法包含FigureClass的行（算法列用//C//分割）
    figure_rows <- index %>%
        filter(!is.na(.data[[algorithm_col]])) %>%
        rowwise() %>%
        filter({
            algos <- strsplit(.data[[algorithm_col]], "//C//", fixed = TRUE)[[1]]
            any(grepl("FigureClass", trimws(algos)))
        }) %>%
        ungroup()
    
    # 按报告维度分组处理
    dim_list <- unique(figure_rows[[dim_col]])
    dim_list <- dim_list[!is.na(dim_list)]
    
    for (dim in dim_list) {
        # 获取该维度对应的行
        dim_rows <- figure_rows %>%
            filter(.data[[dim_col]] == dim)
        
        if (nrow(dim_rows) == 0) next
        
        # 检查Class列是否存在
        class_col <- paste0(dim, "_Class")
        if (!class_col %in% colnames(dat)) {
            warning(paste("维度", dim, "的Class列", class_col, "不存在"))
            next
        }
        
        # 从算法中提取类别（中文括号内的内容）
        # 算法列可能包含多个算法（用//C//分割），需要找到包含FigureClass的部分
        algorithm_full <- dim_rows[[algorithm_col]][1]
        algos_split <- strsplit(algorithm_full, "//C//", fixed = TRUE)[[1]]
        algorithm_str <- algos_split[grepl("FigureClass", algos_split)][1]
        if (is.na(algorithm_str)) {
            warning(paste("无法从算法中找到FigureClass：", algorithm_full))
            next
        }
        algorithm_str <- trimws(algorithm_str)
        # 匹配中文括号内的内容，例如 "FigureClass（表现较好、表现好）"
        match_result <- regmatches(algorithm_str, regexpr("（[^）]+）", algorithm_str))
        if (length(match_result) > 0) {
            # 提取括号内的内容，去掉括号
            classes_str <- gsub("（|）", "", match_result)
            # 分割类别（支持顿号、逗号等分隔符）
            target_classes <- strsplit(classes_str, "[、，, ]+")[[1]]
            target_classes <- trimws(target_classes)  # 去除空格
        } else {
            warning(paste("无法从算法提取类别：", algorithm_str))
            next
        }
        
        # 判断Class列的值是否在目标类别中
        figure_col <- paste0(dim, "_Figure")
        dat[[figure_col]] <- ifelse(
            is.na(dat[[class_col]]),
            NA_real_,
            ifelse(
                dat[[class_col]] %in% target_classes,
                1,
                0
            )
        )
    }
    
    return(dat)
}


# CalFigureRate（3、4、5）：【_Figure】选择345的题目数量占比作为学生指标--然后算指数时平均即可
# 逻辑：index_h中，对于算法【FigureRate】的行：
# 先识别FigureRate后面中文括号内的数字，例如3、4、5，则表示选择3、4、5的题目数量占比作为学生指标。
# dim_list作为参数输入，对每个dim,
# 你需要找到对应的全部列名，然后判断每个学生（一行）在这些题目（列）上，有几个题目的值%in%3、4、5。
# 然后再除以题目总数量，得到占比。
# 将结果赋值给dat_stu_h中paste0(dim,"_Figure")列。
CalFigureRate <- function(dat, index, dim_list,
                          algorithm_col = "算法",
                          dim_col = "报告维度",
                          item_col = "题目列名") {
    # 筛选出算法包含FigureRate的行（算法列用//C//分割）
    rate_rows <- index %>%
        filter(!is.na(.data[[algorithm_col]])) %>%
        rowwise() %>%
        filter({
            algos <- strsplit(.data[[algorithm_col]], "//C//", fixed = TRUE)[[1]]
            any(grepl("FigureRate", trimws(algos)))
        }) %>%
        ungroup()
    
    for (dim in dim_list) {
        # 获取该维度对应的所有题目列名
        dim_rows <- rate_rows %>%
            filter(.data[[dim_col]] == dim)
        
        if (nrow(dim_rows) == 0) {
            warning(paste("维度", dim, "在index中找不到FigureRate配置"))
            next
        }
        
        # 获取该维度对应的所有题目列名
        items <- dim_rows %>%
            pull(.data[[item_col]])
        items <- items[!is.na(items)]
        
        # 检查这些列是否存在于dat中
        existing_items <- items[items %in% colnames(dat)]
        
        if (length(existing_items) == 0) {
            warning(paste("维度", dim, "的题目列在dat中不存在"))
            next
        }
        
        # 从算法中提取数字（中文括号内的内容）
        # 算法列可能包含多个算法（用//C//分割），需要找到包含FigureRate的部分
        algorithm_full <- dim_rows[[algorithm_col]][1]
        algos_split <- strsplit(algorithm_full, "//C//", fixed = TRUE)[[1]]
        algorithm_str <- algos_split[grepl("FigureRate", algos_split)][1]
        if (is.na(algorithm_str)) {
            warning(paste("无法从算法中找到FigureRate：", algorithm_full))
            next
        }
        algorithm_str <- trimws(algorithm_str)
        # 匹配中文括号内的内容，例如 "FigureRate（3、4、5）"
        match_result <- regmatches(algorithm_str, regexpr("（[^）]+）", algorithm_str))
        if (length(match_result) > 0) {
            # 提取括号内的内容，去掉括号
            values_str <- gsub("（|）", "", match_result)
            # 分割数字（支持顿号、逗号、空格等分隔符）
            target_values <- as.numeric(strsplit(values_str, "[、，, ]+")[[1]])
            target_values <- target_values[!is.na(target_values)]
        } else {
            warning(paste("无法从算法提取数字：", algorithm_str))
            next
        }
        
        # 计算每个学生在这些题目上选择目标值的占比
        figure_col <- paste0(dim, "_Figure")
        
        # 对每一行计算占比
        dat[[figure_col]] <- apply(dat[, existing_items, drop = FALSE], 1, function(row) {
            # 转换为数值型
            row_numeric <- as.numeric(row)
            # 计算有多少个值在目标值中
            count <- sum(row_numeric %in% target_values, na.rm = TRUE)
            # 计算总题目数（排除NA）
            total <- sum(!is.na(row_numeric))
            # 返回占比
            if (total == 0) return(NA_real_)
            return(count / total)
        })
    }
    
    return(dat)
}


# SingleChoice_to_Numeric：单选题选项转化为数字
# 对index_h$题型为单选题的题目，将选项转化为数字。数字按照index_h$选项的顺序进行排列。
# 例如选项为：很同意//C//比较同意//C//不确定//C//不太同意
# 某学生在该题目上选择【比较同意】应当转为2。
# 注意：对于包含"_______"的选项（如"其他_________________*"），需要提取"_______"之前的字符串作为选项名称，
# 并使用str_detect进行匹配，因为选项后面可能有特殊字符（如"其他(ccc)"或"其他."等）
SingleChoice_to_Numeric <- function(dat, index,
                                     type_col = "题型",
                                     item_col = "题目列名",
                                     option_col = "选项") {
    library(stringr)
    
    # 筛选出单选题
    single_choice_rows <- index %>%
        filter(!is.na(.data[[type_col]]) & .data[[type_col]] == "单选题")
    
    for (i in seq_len(nrow(single_choice_rows))) {
        # 获取题目列名
        item_name <- single_choice_rows[[item_col]][i]
        if (is.na(item_name) || !item_name %in% colnames(dat)) {
            warning(paste("题目列", item_name, "在dat中不存在"))
            next
        }
        
        # 获取选项
        option_str <- single_choice_rows[[option_col]][i]
        if (is.na(option_str) || option_str == "") {
            warning(paste("题目", item_name, "的选项为空"))
            next
        }
        
        # 用//C//分割选项
        options_raw <- strsplit(option_str, "//C//", fixed = TRUE)[[1]]
        options_raw <- trimws(options_raw)  # 去除首尾空格
        
        # 处理选项：提取选项名称（处理包含"_______"的情况）
        options <- character(length(options_raw))
        has_underscore <- logical(length(options_raw))
        for (j in seq_along(options_raw)) {
            opt <- options_raw[j]
            # 如果包含"_______"，提取"_______"之前的字符串
            if (grepl("_______", opt, fixed = TRUE)) {
                options[j] <- trimws(strsplit(opt, "_______", fixed = TRUE)[[1]][1])
                has_underscore[j] <- TRUE
            } else {
                options[j] <- opt
                has_underscore[j] <- FALSE
            }
        }
        
        # 将选项转化为数字（按照选项顺序）
        dat[[item_name]] <- sapply(dat[[item_name]], function(x) {
            if (is.na(x)) return(NA_real_)
            x_trimmed <- trimws(as.character(x))
            
            # 遍历所有选项，找到匹配的
            for (j in seq_along(options)) {
                if (has_underscore[j]) {
                    # 对于包含"_______"的选项，使用str_detect进行匹配
                    # 选项名称在开头，后面可能有其他字符
                    opt_escaped <- gsub("([.^$*+?(){}[\\|])", "\\\\\\1", options[j])
                    pattern <- paste0("^", opt_escaped)
                    if (str_detect(x_trimmed, pattern)) {
                        return(as.numeric(j))
                    }
                } else {
                    # 对于普通选项，使用精确匹配
                    if (options[j] == x_trimmed) {
                        return(as.numeric(j))
                    }
                }
            }
            
            # 如果没有匹配，返回NA
            return(NA_real_)
        })
    }
    
    return(dat)
}


# MultiChoice_to_Numeric：多选题选项转化为多列（0/1编码）
# 对index_h$题型为多选题的题目，按照选项生成多列
# 每列名称是paste0(题目列名, "_", 选项)
# 某学生在该题目上选择了对应选项则为1；没有选择为0；如果本题原始数据为NA，则所有选项均为NA
# 原始数据使用"|\r\n"分割
# 注意包含"_________*"的选项，需要用"_______"之前的字符串作为选项，并用str_detect进行判断
MultiChoice_to_Numeric <- function(dat, index,
                                    type_col = "题型",
                                    item_col = "题目列名",
                                    option_col = "选项") {
    library(stringr)
    
    # 筛选出多选题
    multi_choice_rows <- index %>%
        filter(!is.na(.data[[type_col]]) & .data[[type_col]] == "多选题")
    
    for (i in seq_len(nrow(multi_choice_rows))) {
        # 获取题目列名
        item_name <- multi_choice_rows[[item_col]][i]
        if (is.na(item_name) || !item_name %in% colnames(dat)) {
            warning(paste("题目列", item_name, "在dat中不存在"))
            next
        }
        
        # 获取原题目列的位置
        item_col_idx <- which(colnames(dat) == item_name)
        
        # 获取选项
        option_str <- multi_choice_rows[[option_col]][i]
        if (is.na(option_str) || option_str == "") {
            warning(paste("题目", item_name, "的选项为空"))
            next
        }
        
        # 用//C//分割选项
        options_raw <- strsplit(option_str, "//C//", fixed = TRUE)[[1]]
        options_raw <- trimws(options_raw)
        
        # 处理选项：提取选项名称（处理包含"__"后面跟着任意数量"_"的情况）
        options <- character(length(options_raw))
        for (j in seq_along(options_raw)) {
            opt <- options_raw[j]
            # 如果包含"__"后面跟着一个或多个"_"，提取"__"之前的字符串
            match_pos <- regexpr("__+", opt)
            if (match_pos[1] > 0) {
                options[j] <- trimws(substr(opt, 1, match_pos[1] - 1))
            } else {
                options[j] <- opt
            }
        }
        
        # 存储该题目创建的所有新列名
        new_col_names <- character(length(options))
        
        # 对每个选项创建新列
        for (j in seq_along(options)) {
            opt_name <- options[j]
            opt_raw <- options_raw[j]
            new_col_name <- paste0(item_name, "_", opt_name)
            new_col_names[j] <- new_col_name
            
            # 初始化新列为0
            dat[[new_col_name]] <- 0
            
            # 处理每一行的数据
            for (row_idx in seq_len(nrow(dat))) {
                original_value <- dat[[item_name]][row_idx]
                
                # 如果原始数据为NA，则新列也为NA
                if (is.na(original_value)) {
                    dat[[new_col_name]][row_idx] <- NA_real_
                } else {
                    # 将原始值转为字符型
                    original_str <- as.character(original_value)
                    
                    # 分割原始数据：先尝试按"|\r\n"拆分，如果没有拆分成功（只有一个元素），再按"|"拆分
                    selected_items <- strsplit(original_str, "\\|\\r\\n", fixed = FALSE)[[1]]
                    # 如果没有拆分成功（只有一个元素），再按"|"拆分
                    if (length(selected_items) == 1 && selected_items[1] == original_str) {
                        selected_items <- strsplit(original_str, "|", fixed = TRUE)[[1]]
                    }
                    selected_items <- trimws(selected_items)
                    
                    # 判断是否选择了该选项
                    is_selected <- FALSE
                    
                    # 检查是否包含"_______"的选项
                    if (grepl("_______", opt_raw, fixed = TRUE)) {
                        # 使用str_detect进行判断
                        # selected_items中的每个元素已经是分割后的单个选项
                        # 选项名称在开头，后面可能有其他字符（包括_______等）
                        # 转义特殊字符
                        opt_escaped <- gsub("([.^$*+?(){}[\\|])", "\\\\\\1", opt_name)
                        pattern <- paste0("^", opt_escaped)
                        is_selected <- any(str_detect(selected_items, pattern))
                    } else {
                        # 精确匹配
                        is_selected <- opt_name %in% selected_items
                    }
                    
                    if (is_selected) {
                        dat[[new_col_name]][row_idx] <- 1
                    }
                }
            }
        }
        
        # 重新排列列的顺序，将新列放在原题目列后面
        # 获取当前所有列名
        all_cols <- colnames(dat)
        # 找到原题目列之前、之后以及新列的索引
        before_cols <- all_cols[1:(item_col_idx - 1)]
        after_cols <- all_cols[(item_col_idx + 1):length(all_cols)]
        # 从after_cols中移除新列（因为它们已经被添加到末尾了）
        after_cols <- setdiff(after_cols, new_col_names)
        # 重新排列：原题目列之前的列 + 原题目列 + 新列 + 原题目列之后的列（排除新列）
        new_col_order <- c(before_cols, item_name, new_col_names, after_cols)
        dat <- dat[, new_col_order]
        
        # 更新item_col_idx，因为列的顺序已经改变
        # 下次循环时，需要重新查找列的位置
    }
    
    return(dat)
}

clean_spss_names <- function(names) {
    # SPSS变量名要求：
    # - 必须以字母或@开头
    # - 只能包含字母、数字、@、#、$、_、.
    # - 不能超过64个字符
    # - 不能包含空格、中文、括号、冒号等特殊字符

    cleaned <- character(length(names))
    
    for (i in seq_along(names)) {
        name <- names[i]
        # 提取所有数字和英文（保留关键信息）
        # 先提取数字部分（保留所有数字，用下划线连接）
        numbers <- regmatches(name, gregexpr("[0-9]+", name))[[1]]
        numbers_str <- ifelse(length(numbers) > 0, paste0(numbers, collapse = "_"), "")
        # 提取英文部分（保留所有英文单词）
        english <- regmatches(name, gregexpr("[A-Za-z]+", name))[[1]]
        english_str <- ifelse(length(english) > 0, paste0(english, collapse = "_"), "")
        
        # 构建基础名称：组合英文和数字
        if (english_str != "" && numbers_str != "") {
            base <- paste0(english_str, "_", numbers_str)
        } else if (english_str != "") {
            base <- english_str
        } else if (numbers_str != "") {
            base <- paste0("Q", numbers_str)
        } else {
            # 如果既没有英文也没有数字，使用序号
            base <- paste0("Var", i)
        }
        
        # 替换不允许的特殊字符为下划线
        base <- gsub("[^A-Za-z0-9@#$_.]", "_", base)
        # 将连续的下划线替换为单个下划线
        base <- gsub("_+", "_", base)
        # 移除开头和结尾的下划线
        base <- gsub("^_+|_+$", "", base)
        # 移除结尾的点
        base <- gsub("\\.+$", "", base)
        
        # 如果以数字开头，添加V前缀
        if (grepl("^[0-9]", base)) {
            base <- paste0("V", base)
        }
        
        # 如果为空，使用默认名称
        if (base == "" || base == "_") {
            base <- paste0("Var", i)
        }
        
        # 截断超过55个字符（留出空间给唯一性后缀）
        base <- substr(base, 1, 55)
        # 再次移除结尾的点
        base <- gsub("\\.+$", "", base)
        
        # 为每个变量添加唯一序号，确保唯一性
        base <- paste0(base, "_", sprintf("%04d", i))
        
        cleaned[i] <- base
    }
    
    # 确保唯一性（SPSS变量名不区分大小写，所以需要统一处理）
    # 先将所有转换为小写进行比较
    cleaned_lower <- tolower(cleaned)
    for (i in seq_along(cleaned)) {
        # 检查是否有重复（不区分大小写）
        matches <- which(cleaned_lower[1:i] == cleaned_lower[i])
        if (length(matches) > 1) {
            # 有重复，修改序号后缀
            suffix <- sprintf("%04d", i)
            base_name <- substr(cleaned[i], 1, 50)
            cleaned[i] <- paste0(base_name, "_", suffix)
            cleaned_lower[i] <- tolower(cleaned[i])
        }
    }
    
    # 最后再次移除结尾的点
    cleaned <- gsub("\\.+$", "", cleaned)
    
    return(cleaned)
}






########################################################
# 报告相关函数
########################################################

# 加载必要的包
library(stringr)
library(ggplot2)
library(gridExtra)
library(psych)
library(corrplot)
library(png)
library(grid)
library(gridExtra)
library(patchwork)

# 1. Cronbach_alpha函数
generate_Cronbach_alpha <- function(dat, index_report_row, index_item, i, color_palette) {
    tryCatch({
        # 获取报告维度（可能多个，用顿号分割）
        dims_str <- index_report_row$报告维度
        if (is.na(dims_str) || dims_str == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        dims <- strsplit(dims_str, "、", fixed = TRUE)[[1]]
        dims <- trimws(dims)
        
        # 初始化结果表格
        result_table <- data.frame(
            参数 = c("题目数量", "克隆巴赫系数"),
            stringsAsFactors = FALSE
        )
        
        # 初始化负相关题目记录表
        negative_corr_items <- data.frame(
            行号 = integer(),
            报告维度 = character(),
            题目列名 = character(),
            是否负相关 = logical(),
            stringsAsFactors = FALSE
        )
        
        # 对每个维度计算Cronbach alpha
        # 根据数据表对应过滤index_item
        index_item_filtered <- filter_index_item_by_data_table(index_item, index_report_row)
        
        for (dim in dims) {
            # 在index_item中找到该维度的所有题目列名
            items <- index_item_filtered %>%
                filter(报告维度 == dim) %>%
                pull(题目列名)
            items <- items[!is.na(items)]
            
            # 检查这些列是否存在于dat中
            existing_items <- items[items %in% colnames(dat)]
            
            if (length(existing_items) == 0) {
                warning(paste("第", i, "行：维度", dim, "在dat中未找到对应的题目列"))
                result_table[[dim]] <- c("0", NA_character_)
                next
            }
            
            # 计算Cronbach alpha
            dat_subset <- dat[, existing_items, drop = FALSE]
            # 移除完全为NA的行
            dat_subset <- dat_subset[complete.cases(dat_subset), , drop = FALSE]
            
            # 确保 dat_subset 至少有2列和足够的非NA行
            if (nrow(dat_subset) == 0 || ncol(dat_subset) < 2) {
                warning(paste("第", i, "行：维度", dim, "没有有效数据或列数不足（需要至少2列）"))
                result_table[[dim]] <- c(as.character(as.integer(length(existing_items))), NA_character_)
                next
            }
            
            # 计算Cronbach alpha
            alpha_result <- tryCatch({
                suppressWarnings(psych::alpha(dat_subset, check.keys = TRUE))
            }, error = function(e) {
                warning(paste("第", i, "行：维度", dim, "计算Cronbach alpha失败：", e$message))
                return(NULL)
            })
            
            if (!is.null(alpha_result)) {
                # 安全地提取 raw_alpha，确保返回长度为1的数值
                alpha_value <- NA_real_
                
                # 检查 alpha_result$total 是否存在
                if (!is.null(alpha_result$total)) {
                    # 尝试提取 raw_alpha
                    raw_alpha_raw <- tryCatch({
                        alpha_result$total$raw_alpha
                    }, error = function(e) {
                        NULL
                    })
                    
                    if (!is.null(raw_alpha_raw)) {
                        # 提取数值：如果是 list，提取第一个元素；如果是向量，提取第一个元素；如果是单个值，直接使用
                        if (is.list(raw_alpha_raw)) {
                            if (length(raw_alpha_raw) > 0) {
                                raw_alpha_numeric <- suppressWarnings(as.numeric(raw_alpha_raw[[1]]))
                            } else {
                                raw_alpha_numeric <- NA_real_
                            }
                        } else {
                            raw_alpha_numeric <- suppressWarnings(as.numeric(raw_alpha_raw[1]))
                        }
                        
                        # 确保是长度为1的数值，否则设为NA（不警告）
                        if (length(raw_alpha_numeric) == 1 && !is.na(raw_alpha_numeric) && is.numeric(raw_alpha_numeric)) {
                            alpha_value <- raw_alpha_numeric
                        } else {
                            alpha_value <- NA_real_
                        }
                    }
                }
                
                # 检查并记录负相关的题目
                if (!is.null(alpha_result$keys)) {
                    keys_vec <- unlist(alpha_result$keys)
                    negative_items <- names(keys_vec)[keys_vec == -1]
                    if (length(negative_items) > 0) {
                        for (item_name in negative_items) {
                            negative_corr_items <- rbind(negative_corr_items, data.frame(
                                行号 = i,
                                报告维度 = dim,
                                题目列名 = item_name,
                                是否负相关 = TRUE,
                                stringsAsFactors = FALSE
                            ))
                        }
                    }
                }
            } else {
                alpha_value <- NA_real_
            }
            
            # 题目数量应为整数，克隆巴赫系数保留3位小数
            # 注意：为了避免R自动将整数列转换为浮点数，我们使用字符类型存储格式化后的值
            item_count_str <- as.character(as.integer(length(existing_items)))
            
            # 安全地处理 alpha_value，确保它是单个数值
            if (is.null(alpha_value) || length(alpha_value) == 0) {
                alpha_str <- NA_character_
            } else if (is.list(alpha_value)) {
                # 如果是 list，尝试提取第一个元素
                if (length(alpha_value) > 0) {
                    alpha_value_numeric <- suppressWarnings(as.numeric(alpha_value[[1]]))
                    if (is.na(alpha_value_numeric) || !is.numeric(alpha_value_numeric)) {
                        alpha_str <- NA_character_
                    } else {
                        alpha_str <- sprintf("%.3f", round(alpha_value_numeric, 3))
                    }
                } else {
                    alpha_str <- NA_character_
                }
            } else if (!is.numeric(alpha_value)) {
                # 如果不是数值，尝试转换
                alpha_value_numeric <- suppressWarnings(as.numeric(alpha_value[1]))
                if (is.na(alpha_value_numeric) || !is.numeric(alpha_value_numeric)) {
                    alpha_str <- NA_character_
                } else {
                    alpha_str <- sprintf("%.3f", round(alpha_value_numeric, 3))
                }
            } else {
                # 已经是数值类型
                alpha_str <- sprintf("%.3f", round(alpha_value[1], 3))
            }
            result_table[[dim]] <- c(item_count_str, alpha_str)
        }
        
        # 在返回前，确保"题目数量"行的所有列都是整数格式的字符串
        # "克隆巴赫系数"行的所有列都是3位小数格式的字符串
        item_count_row <- which(result_table$参数 == "题目数量")
        alpha_row <- which(result_table$参数 == "克隆巴赫系数")
        
        if (length(item_count_row) > 0 && length(alpha_row) > 0) {
            # 处理所有数值列（从第2列开始）
            for (col_idx in 2:ncol(result_table)) {
                # 题目数量行：确保是整数格式的字符串
                item_val <- result_table[[col_idx]][item_count_row]
                if (!is.na(item_val)) {
                    # 如果是数值，转换为整数字符串；如果已经是字符串，确保是整数格式
                    if (is.numeric(item_val)) {
                        result_table[[col_idx]][item_count_row] <- as.character(as.integer(round(item_val)))
                    } else if (is.character(item_val)) {
                        # 如果已经是字符串，尝试转换为整数再转回字符串
                        num_val <- suppressWarnings(as.numeric(item_val))
                        if (!is.na(num_val)) {
                            result_table[[col_idx]][item_count_row] <- as.character(as.integer(round(num_val)))
                        }
                    }
                }
                
                # 克隆巴赫系数行：确保是3位小数格式的字符串
                alpha_val <- result_table[[col_idx]][alpha_row]
                if (!is.na(alpha_val)) {
                    # 如果是数值，格式化为3位小数字符串；如果已经是字符串，确保是3位小数格式
                    if (is.numeric(alpha_val)) {
                        result_table[[col_idx]][alpha_row] <- sprintf("%.3f", round(alpha_val, 3))
                    } else if (is.character(alpha_val)) {
                        # 如果已经是字符串，尝试转换为数值再格式化为3位小数
                        num_val <- suppressWarnings(as.numeric(alpha_val))
                        if (!is.na(num_val)) {
                            result_table[[col_idx]][alpha_row] <- sprintf("%.3f", round(num_val, 3))
                        }
                    }
                }
            }
        }
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_1_Cronbach_alpha.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 保存负相关题目记录（如果有）
        if (nrow(negative_corr_items) > 0) {
            negative_file <- paste0(table_path, "/", i, "_1_Cronbach_alpha_negative_corr_items.csv")
            write.csv(negative_corr_items, negative_file, 
                      row.names = FALSE, fileEncoding = "UTF-8")
            cat("第", i, "行：已保存负相关题目记录至：", negative_file, "\n")
        }
        
        return(result_table)
    }, error = function(e) {
        warning(paste("第", i, "行：Cronbach_alpha函数执行失败：", e$message))
        return(NULL)
    })
}

# 2. simple_bar_dis_figures函数
generate_simple_bar_dis_figures <- function(dat, index_report_row, i, color_palette, figures_with_dot = NULL, hide_other_labels = FALSE, target_district = NULL, 
                                            is_three_level_compare = FALSE, dat_qd = NULL, dat_dist = NULL, school_name = NULL) {
    tryCatch({
        # 获取报告维度
        dim <- index_report_row$报告维度
        if (is.na(dim) || dim == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 获取图表类型，决定指标列名后缀
        chart_type <- index_report_row$图表类型
        is_score_type <- !is.na(chart_type) && chart_type == "simple_bar_dis_score"
        
        if (is_score_type) {
            indicator_col <- paste0(dim, "_Score")
            # Score类型强制保留1位小数
            decimal_digits <- 1
        } else {
            indicator_col <- paste0(dim, "_Figure")
            # 检查是否在figures_with_dot中，决定小数位数
            if (is.null(figures_with_dot)) {
                figures_with_dot <- c()  # 默认为空，保留整数
            }
            use_decimal <- dim %in% figures_with_dot
            decimal_digits <- ifelse(use_decimal, 1, 0)
        }
        
        if(dim %in% c("总分", "量尺分", "原始分")){
            indicator_col <- dim
        }

        if (!indicator_col %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到变量", indicator_col))
            return(NULL)
        }
        
        # 三级对比逻辑
        if (is_three_level_compare) {
            # 检查必要的数据是否提供
            if (is.null(dat_qd) || is.null(dat_dist) || is.null(school_name)) {
                warning(paste("第", i, "行：三级对比模式需要提供dat_qd、dat_dist和school_name参数"))
                return(NULL)
            }
            
            # 检查indicator_col是否在所有数据中存在
            if (!indicator_col %in% colnames(dat_qd) || !indicator_col %in% colnames(dat_dist) || !indicator_col %in% colnames(dat)) {
                warning(paste("第", i, "行：三级对比模式中，indicator_col", indicator_col, "不在所有数据中存在"))
                return(NULL)
            }
            
            # 计算三级对比数据：青岛市、区市、本校
            qd_mean <- mean(dat_qd[[indicator_col]], na.rm = TRUE)
            
            # 获取学校所在区市（从dat_dist中获取，因为dat_dist已经过滤了该区市的数据）
            if ("区市" %in% colnames(dat_dist) && nrow(dat_dist) > 0) {
                school_district <- as.character(unique(dat_dist$区市)[1])
            } else {
                warning(paste("第", i, "行：无法从dat_dist中确定学校所在的区市"))
                return(NULL)
            }
            
            dist_mean <- mean(dat_dist[[indicator_col]], na.rm = TRUE)
            sch_mean <- mean(dat[[indicator_col]], na.rm = TRUE)
            
            # 创建结果表
            result_table <- data.frame(
                区市 = c("青岛市", school_district, "本校"),
                值 = c(qd_mean, dist_mean, sch_mean),
                stringsAsFactors = FALSE
            )
            
            # 设置factor levels
            result_table$区市 <- factor(result_table$区市, levels = c("青岛市", school_district, "本校"))
        } else {
            # 原有逻辑：计算每个区市的指标均值
            result_table <- dat %>%
                group_by(区市) %>%
                summarise(值 = mean(.data[[indicator_col]], na.rm = TRUE), .groups = "drop")
            
            # 计算总体均值
            overall_mean <- mean(dat[[indicator_col]], na.rm = TRUE)
            result_table <- rbind(result_table, data.frame(区市 = "青岛市", 值 = overall_mean))
            
            # 确保区市顺序：青岛市在最前，然后是局属学校，然后是其他
            区市_levels <- c("青岛市", levels(dat$区市))
            result_table$区市 <- factor(result_table$区市, levels = 区市_levels)
            result_table <- result_table[order(result_table$区市), ]
        }
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_2_simple_bar_dis_figures.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 检查图表类型，决定是否显示百分号和breaks间隔
        show_percent <- grepl("simple_bar_dis_figures_percent", chart_type)
        

        # 绘制条形图
        # 去除掉区市为NA的数据
        result_table <- result_table[!is.na(result_table$区市), ]
        # 如果区市的数量超过10个，添加换行符
        if (length(unique(result_table$区市)) > 10) {
            # 先转换为字符向量，添加换行符
            result_table$区市 <- as.character(result_table$区市)
            result_table$区市 <- gsub("西海岸新区", "西海岸\n新区", result_table$区市)
            result_table$区市 <- gsub("局属学校", "局属\n学校", result_table$区市)
            # 更新levels以包含换行符版本
            区市_levels_updated <- 区市_levels
            区市_levels_updated <- gsub("西海岸新区", "西海岸\n新区", 区市_levels_updated)
            区市_levels_updated <- gsub("局属学校", "局属\n学校", 区市_levels_updated)
            # 重新设置为factor，保持顺序
            result_table$区市 <- factor(result_table$区市, levels = 区市_levels_updated)
        }

        # 根据类型决定是否将值转换为百分数
        if (is_score_type) {
            # Score类型：不乘以100，直接使用原始值
            result_table$值_pct <- result_table$值
        } else {
            # Figure类型：将值转换为百分数
            result_table$值_pct <- result_table$值 * 100
        }
        
        # 根据类型决定breaks间隔或自定义breaks
        if (is_score_type) {
            # 先计算Y轴最大值（用于自动设置breaks_interval）
            y_max <- max(result_table$值, na.rm = TRUE)
            
            # 检查是否有自定义的Y轴break设置（从"备注"列读取）
            custom_breaks <- NULL
            if ("备注" %in% colnames(index_report_row) && !is.na(index_report_row$备注) && index_report_row$备注 != "") {
                # 尝试从备注中解析break值（格式如：1,2,3,4,5 或 1:5:1）
                breaks_str <- trimws(as.character(index_report_row$备注))
                # 尝试解析为逗号分隔的数值
                if (grepl(",", breaks_str)) {
                    custom_breaks <- as.numeric(strsplit(breaks_str, ",")[[1]])
                    custom_breaks <- custom_breaks[!is.na(custom_breaks)]
                } else if (grepl(":", breaks_str)) {
                    # 格式如：start:end:step
                    breaks_parts <- strsplit(breaks_str, ":")[[1]]
                    if (length(breaks_parts) == 3) {
                        start_val <- as.numeric(breaks_parts[1])
                        end_val <- as.numeric(breaks_parts[2])
                        step_val <- as.numeric(breaks_parts[3])
                        if (!any(is.na(c(start_val, end_val, step_val)))) {
                            custom_breaks <- seq(start_val, end_val, by = step_val)
                        }
                    }
                } else {
                    # 尝试解析为单个数值（作为间隔）
                    breaks_interval_custom <- as.numeric(breaks_str)
                    if (!is.na(breaks_interval_custom)) {
                        breaks_interval <- breaks_interval_custom
                    } else {
                        # 根据y_max自动设置breaks_interval
                        if (y_max <= 10) {
                            breaks_interval <- 0.5
                        } else if (y_max <= 20) {
                            breaks_interval <- 1
                        } else if (y_max <= 30) {
                            breaks_interval <- 2
                        } else if(y_max <= 50){
                            breaks_interval <- 5
                        } else {
                            breaks_interval <- 10
                        }
                    }

                }
            } else {
                # 没有备注时，根据y_max自动设置breaks_interval
                if (y_max <= 10) {
                    breaks_interval <- 0.5
                } else if (y_max <= 20) {
                    breaks_interval <- 1
                } else if (y_max <= 30) {
                    breaks_interval <- 2
                } else {
                    breaks_interval <- 5
                }
            }
        } else if (show_percent) {
            # 百分比类型：根据最大值自适应设置breaks间隔和上限
            # 先计算转换后的最大值（已经乘以100）
            # y_max_pct <- max(result_table$值_pct, na.rm = TRUE)
            y_max_pct <- 100
            # 根据最大值动态设置breaks间隔
            if (y_max_pct <= 20) {
                breaks_interval <- 5
            } else {
                breaks_interval <- 10
            }
        } else {
            breaks_interval <- 10
        }
        
        # 根据类型和figures_with_dot设置标签格式
        if (is_score_type) {
            # Score类型：ylab强制显示为整数
            y_label_format <- function(x) as.character(round(x, 0))
            # 为geom_text准备label向量（geom_text上的标签仍然可以显示小数）
            result_table$label_text <- sprintf("%.1f", round(result_table$值_pct, decimal_digits))
        } else if (show_percent) {
            # 显示百分号
            y_label_format <- function(x) paste0(round(x, decimal_digits), "%")
            result_table$label_text <- paste0(round(result_table$值_pct, decimal_digits), "%")
        } else {
            # 不显示百分号（但数值不变）
            y_label_format <- function(x) as.character(round(x, decimal_digits))
            result_table$label_text <- as.character(round(result_table$值_pct, decimal_digits))
        }
        
        # 如果 hide_other_labels 为 TRUE，只显示 target_district 的标签
        if (hide_other_labels && !is.null(target_district)) {
            result_table$label_text[result_table$区市 != target_district] <- ""
        }
        
        # 三级对比模式：只显示"本校"的标签
        if (is_three_level_compare) {
            result_table$label_text[result_table$区市 != "本校"] <- ""
        }
        
        # 确定Y轴的breaks和上限
        if (is_score_type && !is.null(custom_breaks) && length(custom_breaks) > 0) {
            # 使用自定义的breaks
            y_breaks <- custom_breaks
            # 确保breaks在合理范围内
            y_max <- max(result_table$值_pct, na.rm = TRUE)
            y_breaks <- y_breaks[y_breaks >= 0 & y_breaks <= y_max * 1.2]
            y_upper_limit <- max(result_table$值_pct, na.rm = TRUE) * 1.15
        } else if (show_percent) {
            # 百分比类型：自适应设置breaks和上限
            # 重新计算最大值（确保变量存在）
            y_max_pct <- max(result_table$值_pct, na.rm = TRUE)
            
            # 计算Y轴上限（动态调整，根据数据大小灵活设置）
            if (y_max_pct <= 0) {
                y_upper_limit <- 10  # 如果最大值<=0，设置默认上限
            } else if (y_max_pct < 20) {
                # 0-20：增加15%或至少5个单位，向上取整到最近的5的倍数
                y_upper_limit <- ceiling(max(y_max_pct * 1.15, y_max_pct + 5) / 5) * 5
            } else if (y_max_pct < 50) {
                # 20-50：增加12%或至少10个单位，向上取整到最近的10的倍数
                y_upper_limit <- ceiling(max(y_max_pct * 1.12, y_max_pct + 10) / 10) * 10
            } else if (y_max_pct < 80) {
                # 50-80：增加10%或至少10个单位，向上取整到最近的10的倍数
                y_upper_limit <- ceiling(max(y_max_pct * 1.1, y_max_pct + 10) / 10) * 10
            } else {
                # 80-100：向上取整到100，但不超过105
                y_upper_limit <- min(105, ceiling(max(y_max_pct * 1.05, y_max_pct + 5) / 5) * 5)
            }
            
            # 生成breaks（breaks_interval已经在上面根据y_max_pct设置过了）
            y_breaks <- seq(0, y_upper_limit, by = breaks_interval)
        } else {
            # 使用自动生成的breaks
            y_max <- max(result_table$值_pct, na.rm = TRUE)
            y_breaks <- seq(0, y_max + breaks_interval, by = breaks_interval)
            y_upper_limit <- max(result_table$值_pct, na.rm = TRUE) * 1.15
        }
        
        # 动态创建颜色映射
        unique_qu_shi <- levels(result_table$区市)
        color_values <- rep(color_palette$color_1[1], length(unique_qu_shi))
        names(color_values) <- unique_qu_shi
        
        if (is_three_level_compare) {
            # 三级对比模式：本校使用高亮色
            if ("本校" %in% names(color_values)) {
                color_values["本校"] <- color_palette$color_1_highlight[1]
            }
        } else {
            # 原有逻辑：青岛市使用高亮色
            if ("青岛市" %in% names(color_values)) {
                color_values["青岛市"] <- color_palette$color_1_highlight[1]
            }
        }
        
        p <- ggplot(result_table, aes(x = 区市, y = 值_pct, fill = 区市)) +
            geom_bar(stat = "identity", width = 0.4) +
            geom_text(aes(label = label_text), vjust = -0.5, size = 3) +
            scale_fill_manual(values = color_values) +
            labs(caption = ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题),
                 x = "", y = "") +
            scale_y_continuous(labels = y_label_format, 
                             breaks = y_breaks,
                             limits = c(0, y_upper_limit),
                             expand = c(0, 0)) +
            theme_minimal() +
            theme(legend.position = "none",
                  plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                  plot.caption.position = "plot",  # 相对于整个绘图区域居中
                  axis.text.x = element_text(angle = 0),
                  panel.grid = element_blank(),  # 去掉所有背景网格线
                  axis.line = element_line(color = "black"))  # 添加X轴和Y轴线
        
        # 设置高度属性
        attr(p, "plot_height") <- 2.5
        
        return(list(table = result_table, plot = p))
    }, error = function(e) {
        warning(paste("第", i, "行：simple_bar_dis_figures函数执行失败：", e$message))
        return(NULL)
    })
}

# 3. simple_bar_subdim_figures函数
generate_simple_bar_subdim_figures <- function(dat, index_report_row, index_item, i, color_palette, figures_with_dot = NULL) {
    tryCatch({
        # 获取报告维度
        dim <- index_report_row$报告维度
        if (is.na(dim) || dim == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 根据数据表对应过滤index_item
        index_item_filtered <- filter_index_item_by_data_table(index_item, index_report_row)
        
        # 根据图表类型决定使用哪种后缀
        chart_type <- index_report_row$图表类型
        if (grepl("simple_bar_subdim_score", chart_type)) {
            # 使用 _Score 后缀
            suffix <- "_Score"
            use_score <- TRUE
            # Score类型强制保留2位小数
            decimal_digits <- 2
        } else {
            # 使用 _Figure 后缀（默认）
            suffix <- "_Figure"
            use_score <- FALSE
            # 检查是否在figures_with_dot中，决定小数位数
            if (is.null(figures_with_dot)) {
                figures_with_dot <- c()  # 默认为空，保留整数
            }
            use_decimal <- dim %in% figures_with_dot
            decimal_digits <- ifelse(use_decimal, 1, 0)
        }
        
        # 在index_item中找到该维度的所有子维度
        subdims <- index_item_filtered %>%
            filter(报告维度 == dim, !is.na(子维度)) %>%
            pull(子维度) %>%
            unique()
        
        if (length(subdims) == 0) {
            warning(paste("第", i, "行：维度", dim, "未找到子维度"))
            return(NULL)
        }
        
        # 构建指标列名
        indicator_cols <- paste0(subdims, suffix)
        
        # 检查哪些列存在
        existing_cols <- indicator_cols[indicator_cols %in% colnames(dat)]
        if (length(existing_cols) == 0) {
            warning(paste("第", i, "行：未找到任何子维度指标列"))
            return(NULL)
        }
        
        # 计算总体均值
        result_table <- data.frame(
            指标 = character(),
            值 = numeric(),
            stringsAsFactors = FALSE
        )
        
        for (col in existing_cols) {
            mean_val <- mean(dat[[col]], na.rm = TRUE)
            # 去掉后缀（suffix已经包含下划线，如"_Figure"或"_Score"）
            indicator_name <- gsub(paste0(suffix, "$"), "", col)
            result_table <- rbind(result_table, data.frame(指标 = indicator_name, 值 = mean_val))
        }
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_3_simple_bar_subdim_figures.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 绘制横向条形图
        if (use_score) {
            # Score类型：直接使用原始值，不转换为百分数
            result_table$值_plot <- result_table$值
            # x轴最大值：max向上取整+0.3
            x_max <- ceiling(max(result_table$值_plot, na.rm = TRUE)) + 0.3
            x_breaks <- seq(0, x_max, by = 0.5)
            x_limits <- c(0, x_max)
        } else {
            # Figure类型：将值转换为百分数
            result_table$值_plot <- result_table$值 * 100
            x_max <- 105
            x_breaks <- seq(0, 100, by = 10)
            x_limits <- c(0, 105)
        }
        
        # 定义label格式化函数
        if (use_score) {
            label_format <- function(x) sprintf("%.2f", round(x, decimal_digits))
            # 为geom_text准备label向量
            result_table$label_text <- sprintf("%.2f", round(result_table$值_plot, decimal_digits))
        } else {
            label_format <- function(x) as.character(round(x, decimal_digits))
            # 为geom_text准备label向量
            result_table$label_text <- as.character(round(result_table$值_plot, decimal_digits))
        }
        
        p <- ggplot(result_table, aes(x = 值_plot, y = reorder(指标, 值_plot))) +
            geom_bar(stat = "identity", fill = color_palette$color_1[1], width = 0.4) +
            geom_text(aes(label = label_text), 
                     hjust = -0.1, size = 3) +
            labs(caption = ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题),
                 x = "", y = "") +
            scale_x_continuous(labels = label_format,
                             breaks = x_breaks,
                             limits = x_limits,
                             expand = c(0, 0)) +
            theme_minimal() +
            theme(legend.position = "none",
                  plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                  plot.caption.position = "plot",  # 相对于整个绘图区域居中
                  axis.text.y = element_text(angle = 0),
                  panel.grid = element_blank(),  # 去掉所有背景网格线
                  axis.line = element_line(color = "black"))  # 添加X轴和Y轴线
        
        # 设置高度属性
        attr(p, "plot_height") <- 2.5
        
        return(list(table = result_table, plot = p))
    }, error = function(e) {
        warning(paste("第", i, "行：simple_bar_subdim_figures函数执行失败：", e$message))
        return(NULL)
    })
}

# 4. table_figures函数
generate_table_figures <- function(dat, index_report_row, i, color_palette, figures_with_dot = NULL) {
    tryCatch({
        # 获取报告维度（可能多个，用顿号分割）
        dims_str <- index_report_row$报告维度
        if (is.na(dims_str) || dims_str == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        dims <- strsplit(dims_str, "、", fixed = TRUE)[[1]]
        dims <- trimws(dims)
        
        # 检查是否在figures_with_dot中，决定小数位数
        if (is.null(figures_with_dot)) {
            figures_with_dot <- c()  # 默认为空，保留整数
        }
        
        # 构建指标列名
        indicator_cols <- paste0(dims, "_Figure")
        
        # 检查哪些列存在
        existing_cols <- indicator_cols[indicator_cols %in% colnames(dat)]
        if (length(existing_cols) == 0) {
            warning(paste("第", i, "行：未找到任何指标列"))
            return(NULL)
        }
        
        # 计算总体均值
        result_list <- list()
        
        for (col in existing_cols) {
            mean_val <- mean(dat[[col]], na.rm = TRUE)
            # 去掉"_Figure"后缀
            indicator_name <- gsub("_Figure$", "", col)
            # 检查该指标是否在figures_with_dot中
            use_decimal <- indicator_name %in% figures_with_dot
            decimal_digits <- ifelse(use_decimal, 1, 0)
            # 根据小数位数格式化值（保留原始值，在写入Word时格式化）
            result_list[[indicator_name]] <- mean_val
            # 存储小数位数信息（作为属性）
            attr(result_list[[indicator_name]], "decimal_digits") <- decimal_digits
        }
        
        # 转置：将指标名称作为列名
        result_table <- data.frame(result_list, stringsAsFactors = FALSE)
        # 存储小数位数信息
        attr(result_table, "decimal_digits") <- sapply(dims, function(d) ifelse(d %in% figures_with_dot, 1, 0))
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_4_table_figures.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        return(result_table)
    }, error = function(e) {
        warning(paste("第", i, "行：table_figures函数执行失败：", e$message))
        return(NULL)
    })
}

# 4.5. table_dims_score函数
generate_table_dims_score <- function(dat, index_report_row, i, color_palette, figures_with_dot = NULL) {
    tryCatch({
        # 获取报告维度（可能多个，用顿号分割）
        dims_str <- index_report_row$报告维度
        if (is.na(dims_str) || dims_str == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        dims <- strsplit(dims_str, "、", fixed = TRUE)[[1]]
        dims <- trimws(dims)
        
        # 获取图表类型，决定指标列名后缀和小数位数
        chart_type <- index_report_row$图表类型
        is_score_type <- !is.na(chart_type) && chart_type == "table_dims_score"
        is_percent_type <- !is.na(chart_type) && grepl("table_dims_figures_percent", chart_type)
        is_figures_type <- !is.na(chart_type) && chart_type == "table_dims_figures"
        
        # 根据图表类型确定后缀
        if (is_score_type) {
            suffix <- "_Score"
            # Score类型强制保留1位小数
            decimal_digits <- 1
        } else {
            suffix <- "_Figure"
            # Figure类型：检查是否在figures_with_dot中，决定小数位数
            
            if (sum(dims %in% figures_with_dot) == 0) {
                decimal_digits <- 0  # 默认为空，保留整数
            }else{
                decimal_digits <- 1
            }
        }
        
        # 构建指标列名
        indicator_cols <- paste0(dims, suffix)
        
        # 处理特殊维度（总分、量尺分、原始分）
        for (idx in seq_along(dims)) {
            if (dims[idx] %in% c("总分", "量尺分", "原始分")) {
                indicator_cols[idx] <- dims[idx]
            }
        }
        
        # 计算总体均值
        result_list <- list()
        
        # 遍历所有维度，找到对应的列并计算均值
        for (dim_idx in seq_along(dims)) {
            dim_name <- dims[dim_idx]
            col <- indicator_cols[dim_idx]
            
            # 检查该列是否存在
            if (!col %in% colnames(dat)) {
                warning(paste("第", i, "行：维度", dim_name, "对应的列", col, "不存在"))
                next
            }
            
            mean_val <- mean(dat[[col]], na.rm = TRUE)
            
            # 根据小数位数格式化数值
            
            if(is_score_type){
                mean_val <- round(mean_val, decimal_digits)
            } else {
                mean_val <- round(mean_val * 100, decimal_digits)
            }

            if(is_percent_type){
                mean_val <- paste0(mean_val, "%")
            }
            
            # 如果dim_name在c("作业","补习","睡眠","学习压力")里面，添加"指数"后缀
            display_name <- dim_name
            if (dim_name %in% c("作业", "补习", "睡眠", "学习压力")) {
                display_name <- paste0(dim_name, "指数")
            }
            
            result_list[[display_name]] <- mean_val
            # # 存储小数位数信息（作为属性）
            # attr(result_list[[dim_name]], "decimal_digits") <- decimal_digits
        }
        
        # 检查是否有有效的计算结果
        if (length(result_list) == 0) {
            warning(paste("第", i, "行：未找到任何有效的指标列"))
            return(NULL)
        }
        
        # 转置：将指标名称作为列名
        result_table <- data.frame(result_list, stringsAsFactors = FALSE)
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_4.5_table_dims_score.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        return(result_table)
    }, error = function(e) {
        warning(paste("第", i, "行：table_dims_score函数执行失败：", e$message))
        return(NULL)
    })
}

# 5. table_basic_infor_figures函数
generate_table_basic_infor_figures <- function(dat, index_report_row, i, color_palette, figures_with_dot = NULL) {
    tryCatch({
        # 获取报告维度（可能多个，用顿号分割）
        dims_str <- index_report_row$报告维度
        if (is.na(dims_str) || dims_str == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        dims <- strsplit(dims_str, "、", fixed = TRUE)[[1]]
        dims <- trimws(dims)
        
        # 检查是否在figures_with_dot中，决定小数位数
        if (is.null(figures_with_dot)) {
            figures_with_dot <- c()  # 默认为空，保留整数
        }
        
        # 构建指标列名
        indicator_cols <- paste0(dims, "_Figure")
        
        # 检查哪些列存在
        existing_cols <- indicator_cols[indicator_cols %in% colnames(dat)]
        if (length(existing_cols) == 0) {
            warning(paste("第", i, "行：未找到任何指标列"))
            return(NULL)
        }
        
        # 基本信息变量及其levels
        basic_info_vars <- list(
            Gen = list(name = "性别", levels = c("男", "女")),
            Loc = list(name = "城乡", levels = c("乡村", "镇驻地", "城区")),
            Fam = list(name = "家庭结构", levels = c("完整家庭", "父母离婚", "父亲或母亲去世")),
            Sim = list(name = "子女数量", levels = c("独生子女", "二孩", "多孩")),
            Edu_m = list(name = "母亲学历", levels = c("初中及以下", "高中", "大专", "大学本科及以上")),
            Edu_f = list(name = "父亲学历", levels = c("初中及以下", "高中", "大专", "大学本科及以上"))
            # SES = list(name = "家庭教育投入", levels = c("较低", "较高"))
        )
        
        # 初始化结果表格
        result_table <- data.frame(
            分类 = character(),
            类别 = character(),
            stringsAsFactors = FALSE
        )
        
        # 为每个指标添加列
        for (col in existing_cols) {
            indicator_name <- gsub("_Figure$", "", col)
            result_table[[indicator_name]] <- numeric()
        }
        
        # 对每个基本信息变量计算均值
        for (var_name in names(basic_info_vars)) {
            if (!var_name %in% colnames(dat)) {
                next
            }
            
            var_info <- basic_info_vars[[var_name]]
            
            for (level in var_info$levels) {
                # 筛选该类别下的数据
                dat_subset <- dat[dat[[var_name]] == level & !is.na(dat[[var_name]]), ]
                
                if (nrow(dat_subset) == 0) {
                    next
                }
                
                # 计算每个指标的均值
                row_data <- data.frame(
                    分类 = var_info$name,
                    类别 = level,
                    stringsAsFactors = FALSE
                )
                
                for (col in existing_cols) {
                    mean_val <- mean(dat_subset[[col]], na.rm = TRUE) * 100
                    indicator_name <- gsub("_Figure$", "", col)
                    # 检查该指标是否在figures_with_dot中
                    use_decimal <- indicator_name %in% figures_with_dot
                    decimal_digits <- ifelse(use_decimal, 1, 0)
                    row_data[[indicator_name]] <- round(mean_val, decimal_digits)
                }
                
                result_table <- rbind(result_table, row_data)
            }
        }
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_5_table_basic_infor_figures.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        return(result_table)
    }, error = function(e) {
        warning(paste("第", i, "行：table_basic_infor_figures函数执行失败：", e$message))
        return(NULL)
    })
}

# 6. table_cnt_stu函数 - 生成学生计数统计表格
generate_table_cnt_stu <- function(dat, index_report_row, i, color_palette, 
                                    left_vars = NULL, right_vars = NULL, var_name_mapping = NULL, return_text = FALSE) {
    tryCatch({
        # 控制变量名称映射
        control_var_name_mapping <- c(
            "Gen" = "性别",
            "Loc" = "居住地",
            "Fam" = "家庭结构",
            "Sim" = "子女数量",
            "Edu_m" = "母亲学历",
            "Edu_f" = "父亲学历",
            "SES" = "家庭教育投入",
            "是否住宿" = "是否住宿"
        )
        
        # 如果没有提供参数，使用默认值（向后兼容）
        if (is.null(left_vars)) {
            left_vars <- c("Gen", "Sim", "Edu_m")
        }
        if (is.null(right_vars)) {
            right_vars <- c("Sim", "Loc", "Edu_f")
        }
        if (is.null(var_name_mapping)) {
            var_name_mapping <- control_var_name_mapping
        }
        
        # 计算总人数
        total_n <- nrow(dat)
        
        # 构建左侧数据
        left_data <- data.frame(
            分类 = character(),
            类别 = character(),
            人数 = integer(),
            百分比 = numeric(),
            stringsAsFactors = FALSE
        )
        
        for (var_name in left_vars) {
            if (!var_name %in% colnames(dat)) {
                next
            }
            
            # 从dat中获取变量名称（中文名）
            var_name_cn <- ifelse(var_name %in% names(var_name_mapping), 
                                  var_name_mapping[var_name], 
                                  var_name)
            
            # 从dat中获取levels（如果变量是factor类型）
            if (is.factor(dat[[var_name]])) {
                var_levels <- levels(dat[[var_name]])
            } else {
                # 如果不是factor，获取唯一值
                var_levels <- unique(dat[[var_name]])
                var_levels <- var_levels[!is.na(var_levels)]
            }
            
            for (level in var_levels) {
                # 将变量转换为字符型，确保比较的一致性（处理factor类型）
                var_values <- as.character(dat[[var_name]])
                # 计算该类别下的人数（使用字符型比较）
                count <- sum(var_values == as.character(level) & !is.na(var_values), na.rm = TRUE)
                if (count > 0) {
                    pct <- round(count / total_n * 100, 1)
                    left_data <- rbind(left_data, data.frame(
                        分类 = var_name_cn,
                        类别 = as.character(level),
                        人数 = count,
                        百分比 = pct,
                        stringsAsFactors = FALSE
                    ))
                }
            }
            
            # 如果var_name是Gen，插入一个空行
            if (var_name == "Gen" && index_report_row$报告学段 != "中职") {
                left_data <- rbind(left_data, data.frame(
                    分类 = "",
                    类别 = "",
                    人数 = NA_integer_,
                    百分比 = NA_real_,
                    stringsAsFactors = FALSE
                ))
            }
        }
        
        # 构建右侧数据
        right_data <- data.frame(
            分类 = character(),
            类别 = character(),
            人数 = integer(),
            百分比 = numeric(),
            stringsAsFactors = FALSE
        )
        
        for (var_name in right_vars) {
            if (!var_name %in% colnames(dat)) {
                next
            }
            
            # 从dat中获取变量名称（中文名）
            var_name_cn <- ifelse(var_name %in% names(var_name_mapping), 
                                  var_name_mapping[var_name], 
                                  var_name)
            
            # 从dat中获取levels（如果变量是factor类型）
            if (is.factor(dat[[var_name]])) {
                var_levels <- levels(dat[[var_name]])
            } else {
                # 如果不是factor，获取唯一值
                var_levels <- unique(dat[[var_name]])
                var_levels <- var_levels[!is.na(var_levels)]
            }
            
            for (level in var_levels) {
                # 将变量转换为字符型，确保比较的一致性（处理factor类型）
                var_values <- as.character(dat[[var_name]])
                # 计算该类别下的人数（使用字符型比较）
                count <- sum(var_values == as.character(level) & !is.na(var_values), na.rm = TRUE)
                if (count > 0) {
                    pct <- round(count / total_n * 100, 1)
                    right_data <- rbind(right_data, data.frame(
                        分类 = var_name_cn,
                        类别 = as.character(level),
                        人数 = count,
                        百分比 = pct,
                        stringsAsFactors = FALSE
                    ))
                }
            }
        }
        
        # 确定最大行数（用于对齐）
        max_rows <- max(nrow(left_data), nrow(right_data))
        
        # 创建左右并排的表格
        combined_table <- data.frame(
            分类 = character(max_rows),
            类别 = character(max_rows),
            人数 = integer(max_rows),
            百分比 = numeric(max_rows),
            分类.1 = character(max_rows),
            类别.1 = character(max_rows),
            人数.1 = integer(max_rows),
            百分比.1 = numeric(max_rows),
            stringsAsFactors = FALSE,
            check.names = FALSE
        )
        
        # 填充左侧数据
        for (r in seq_len(nrow(left_data))) {
            combined_table$分类[r] <- left_data$分类[r]
            combined_table$类别[r] <- left_data$类别[r]
            combined_table$人数[r] <- left_data$人数[r]
            combined_table$百分比[r] <- left_data$百分比[r]
        }
        
        # 对于左侧数据未填充的行，将人数和百分比设置为NA（以便后续替换为空字符串）
        if (nrow(left_data) < max_rows) {
            for (r in (nrow(left_data) + 1):max_rows) {
                combined_table$人数[r] <- NA_integer_
                combined_table$百分比[r] <- NA_real_
            }
        }
        
        # 填充右侧数据
        for (r in seq_len(nrow(right_data))) {
            combined_table$分类.1[r] <- right_data$分类[r]
            combined_table$类别.1[r] <- right_data$类别[r]
            combined_table$人数.1[r] <- right_data$人数[r]
            combined_table$百分比.1[r] <- right_data$百分比[r]
        }
        
        # 对于右侧数据未填充的行，将人数.1和百分比.1设置为NA（以便后续替换为空字符串）
        if (nrow(right_data) < max_rows) {
            for (r in (nrow(right_data) + 1):max_rows) {
                combined_table$人数.1[r] <- NA_integer_
                combined_table$百分比.1[r] <- NA_real_
            }
        }
        
        # 将NA替换为空字符串
        combined_table[is.na(combined_table)] <- ""
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(combined_table, paste0(table_path, "/", i, "_table_cnt_stu.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 如果需要返回文本，生成文本
        if (return_text) {
            text <- paste0("本区（市）共回收有效问卷", total_n, "份，有效参测比例约为100%。样本分布情况如下。")
            return(list(table = combined_table, text = text))
        } else {
            return(combined_table)
        }
    }, error = function(e) {
        warning(paste("第", i, "行：table_cnt_stu函数执行失败：", e$message))
        return(NULL)
    })
}

# 7. table_cnt_tea函数 - 生成教师计数统计表格
generate_table_cnt_tea <- function(dat, index_report_row, i, color_palette,
                                    left_vars = NULL, right_vars = NULL, var_name_mapping = NULL) {
    tryCatch({
        # 如果没有提供参数，使用默认值（向后兼容）
        if (is.null(left_vars)) {
            left_vars <- c("Gen", "Age", "Edu")
        }
        if (is.null(right_vars)) {
            right_vars <- c("Exp", "Tit")
        }
        if (is.null(var_name_mapping)) {
            var_name_mapping <- c(
                "Gen" = "性别",
                "Age" = "年龄",
                "Exp" = "教龄",
                "Edu" = "学历",
                "Tit" = "职称"
            )
        }
        
        # 计算总人数
        total_n <- nrow(dat)
        
        # 构建左侧数据
        left_data <- data.frame(
            分类 = character(),
            类别 = character(),
            人数 = integer(),
            百分比 = numeric(),
            stringsAsFactors = FALSE
        )
        
        for (var_name in left_vars) {
            if (!var_name %in% colnames(dat)) {
                next
            }
            
            # 从dat中获取变量名称（中文名）
            var_name_cn <- ifelse(var_name %in% names(var_name_mapping), 
                                  var_name_mapping[var_name], 
                                  var_name)
            
            # 从dat中获取levels（如果变量是factor类型）
            if (is.factor(dat[[var_name]])) {
                var_levels <- levels(dat[[var_name]])
            } else {
                # 如果不是factor，获取唯一值
                var_levels <- unique(dat[[var_name]])
                var_levels <- var_levels[!is.na(var_levels)]
            }
            
            for (level in var_levels) {
                # 将变量转换为字符型，确保比较的一致性（处理factor类型）
                var_values <- as.character(dat[[var_name]])
                # 计算该类别下的人数（使用字符型比较）
                count <- sum(var_values == as.character(level) & !is.na(var_values), na.rm = TRUE)
                if (count > 0) {
                    pct <- round(count / total_n * 100, 1)
                    left_data <- rbind(left_data, data.frame(
                        分类 = var_name_cn,
                        类别 = as.character(level),
                        人数 = count,
                        百分比 = pct,
                        stringsAsFactors = FALSE
                    ))
                }
            }
        }
        
        # 构建右侧数据
        right_data <- data.frame(
            分类 = character(),
            类别 = character(),
            人数 = integer(),
            百分比 = numeric(),
            stringsAsFactors = FALSE
        )
        
        for (var_name in right_vars) {
            if (!var_name %in% colnames(dat)) {
                next
            }
            
            # 从dat中获取变量名称（中文名）
            var_name_cn <- ifelse(var_name %in% names(var_name_mapping), 
                                  var_name_mapping[var_name], 
                                  var_name)
            
            # 从dat中获取levels（如果变量是factor类型）
            if (is.factor(dat[[var_name]])) {
                var_levels <- levels(dat[[var_name]])
            } else {
                # 如果不是factor，获取唯一值
                var_levels <- unique(dat[[var_name]])
                var_levels <- var_levels[!is.na(var_levels)]
            }
            
            for (level in var_levels) {
                # 将变量转换为字符型，确保比较的一致性（处理factor类型）
                var_values <- as.character(dat[[var_name]])
                # 计算该类别下的人数（使用字符型比较）
                count <- sum(var_values == as.character(level) & !is.na(var_values), na.rm = TRUE)
                if (count > 0) {
                    pct <- round(count / total_n * 100, 1)
                    right_data <- rbind(right_data, data.frame(
                        分类 = var_name_cn,
                        类别 = as.character(level),
                        人数 = count,
                        百分比 = pct,
                        stringsAsFactors = FALSE
                    ))
                }
            }
        }
        
        # 确定最大行数（用于对齐）
        max_rows <- max(nrow(left_data), nrow(right_data))
        
        # 创建左右并排的表格
        combined_table <- data.frame(
            分类 = character(max_rows),
            类别 = character(max_rows),
            人数 = integer(max_rows),
            百分比 = numeric(max_rows),
            分类.1 = character(max_rows),
            类别.1 = character(max_rows),
            人数.1 = integer(max_rows),
            百分比.1 = numeric(max_rows),
            stringsAsFactors = FALSE,
            check.names = FALSE
        )
        
        # 填充左侧数据
        for (r in seq_len(nrow(left_data))) {
            combined_table$分类[r] <- left_data$分类[r]
            combined_table$类别[r] <- left_data$类别[r]
            combined_table$人数[r] <- left_data$人数[r]
            combined_table$百分比[r] <- left_data$百分比[r]
        }
        
        # 对于左侧数据未填充的行，将人数和百分比设置为NA（以便后续替换为空字符串）
        if (nrow(left_data) < max_rows) {
            for (r in (nrow(left_data) + 1):max_rows) {
                combined_table$人数[r] <- NA_integer_
                combined_table$百分比[r] <- NA_real_
            }
        }
        
        # 填充右侧数据
        for (r in seq_len(nrow(right_data))) {
            combined_table$分类.1[r] <- right_data$分类[r]
            combined_table$类别.1[r] <- right_data$类别[r]
            combined_table$人数.1[r] <- right_data$人数[r]
            combined_table$百分比.1[r] <- right_data$百分比[r]
        }
        
        # 对于右侧数据未填充的行，将人数.1和百分比.1设置为NA（以便后续替换为空字符串）
        if (nrow(right_data) < max_rows) {
            for (r in (nrow(right_data) + 1):max_rows) {
                combined_table$人数.1[r] <- NA_integer_
                combined_table$百分比.1[r] <- NA_real_
            }
        }
        
        # 将NA替换为空字符串
        combined_table[is.na(combined_table)] <- ""
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(combined_table, paste0(table_path, "/", i, "_table_cnt_tea.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        return(combined_table)
    }, error = function(e) {
        warning(paste("第", i, "行：table_cnt_tea函数执行失败：", e$message))
        return(NULL)
    })
}

# 8. table_items函数
generate_table_items <- function(dat, index_report_row, index_item, i, color_palette) {
    tryCatch({
        # 获取报告维度
        dim <- index_report_row$报告维度
        if (is.na(dim) || dim == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 根据数据表对应过滤index_item
        index_item_filtered <- filter_index_item_by_data_table(index_item, index_report_row)
        
        # 在index_item中找到该维度的所有题目列名（是否例题不为NA）
        # 首先在"报告维度"列中查找
        items <- index_item_filtered %>%
            filter(报告维度 == dim, !is.na(是否例题)) %>%
            pull(题目列名)
        items <- items[!is.na(items)]
        
        # 如果找不到，则在"子维度"列中查找
        if (length(items) == 0 && "子维度" %in% colnames(index_item_filtered)) {
            items <- index_item_filtered %>%
                filter(子维度 == dim, !is.na(是否例题)) %>%
                pull(题目列名)
            items <- items[!is.na(items)]
        }
        
        # 如果都找不到，报warning
        if (length(items) == 0) {
            warning(paste("第", i, "行：维度", dim, "未找到题目（在报告维度和子维度中都未找到）"))
            return(NULL)
        }
        
        # 先按选项分组题目
        # 为每个题目获取其选项，并按选项分组
        items_with_options <- list()
        for (item in items) {
            item_row <- index_item_filtered %>% filter(题目列名 == item)
            if (nrow(item_row) > 0) {
                options_str <- item_row$选项
                if (!is.na(options_str) && options_str != "") {
                    options <- strsplit(options_str, "//C//", fixed = TRUE)[[1]]
                    options <- trimws(options)
                    # 将选项转换为字符串作为分组键
                    options_key <- paste(sort(options), collapse = "|||")
                    if (!options_key %in% names(items_with_options)) {
                        items_with_options[[options_key]] <- list(items = c(), options = options)
                    }
                    items_with_options[[options_key]]$items <- c(items_with_options[[options_key]]$items, item)
                }
            }
        }
        
        # 为每个选项组生成独立的表格
        result_tables <- list()
        
        for (options_key in names(items_with_options)) {
            group_items <- items_with_options[[options_key]]$items
            group_options <- items_with_options[[options_key]]$options
            
            # 初始化该组的表格
            group_table <- data.frame(题目 = character(), stringsAsFactors = FALSE)
            for (opt in group_options) {
                group_table[[opt]] <- character()
            }
            
            for (item in group_items) {
                # 检查是否需要反向处理
                item_row <- index_item_filtered %>% filter(题目列名 == item)
                if (nrow(item_row) == 0) {
                    warning(paste("第", i, "行：在index_item中未找到题目", item))
                    next
                }
                is_reverse <- !is.na(item_row$是否反向) && item_row$是否反向 != ""
                
                # 检查是否需要使用"_处理前"后缀的列
                # 如果报告维度是抑郁倾向、焦虑倾向、抑郁情绪或焦虑情绪，且当前item属于该维度，需要使用"_处理前"后缀
                use_before_processing <- FALSE
                if (index_report_row$报告维度 %in% c("抑郁倾向", "焦虑倾向", "抑郁情绪", "焦虑情绪", "师德师风家长评价")) {
                    # 检查item是否属于该报告维度
                    item_dim <- item_row$报告维度[1]
                    if (!is.na(item_dim) && item_dim == dim) {
                        use_before_processing <- TRUE
                    }
                }
                
                # 确定dat中的列名
                if (is_reverse && use_before_processing) {
                    # 如果需要反向处理，直接使用"item_反向前"（不需要再加"_处理前"）
                    dat_col <- paste0(item, "_反向前_处理前")
                } else if (is_reverse) {
                    # 如果需要反向处理，直接使用"item_反向前"（不需要再加"_处理前"）
                    dat_col <- paste0(item, "_反向前")
                } else if (use_before_processing) {
                    # 如果不需要反向处理但需要使用处理前的数据，添加"_处理前"后缀
                    dat_col <- paste0(item, "_处理前")
                } else {
                    # 普通情况，直接使用item
                    dat_col <- item
                }
                
                # 如果精确匹配失败，尝试模糊匹配
                if (!dat_col %in% colnames(dat)) {
                    # 提取题目的关键部分进行模糊匹配
                    if (grepl("--", item, fixed = TRUE)) {
                        # 方法1：提取"--数字.题目文本"部分（例如"--1.你对你和老师的关系满意吗"）
                        match_result <- regmatches(item, regexpr("--[0-9]+\\.(.+)", item))
                        if (length(match_result) > 0) {
                            item_key <- sub("^--[0-9]+\\.", "", match_result[1])
                            item_key <- trimws(item_key)
                            
                            # 在dat的列名中查找包含这个关键文本的列（去除空格后比较）
                            dat_cols_trimmed <- trimws(colnames(dat))
                            matching_cols <- colnames(dat)[grepl(item_key, dat_cols_trimmed, fixed = TRUE)]
                            
                            if (length(matching_cols) > 0) {
                                # 如果需要使用处理前的数据，优先选择带"_处理前"后缀的列
                                if (use_before_processing) {
                                    matching_cols_before <- matching_cols[grepl("_处理前$", matching_cols)]
                                    if (length(matching_cols_before) > 0) {
                                        matching_cols <- matching_cols_before
                                    }
                                }
                                
                                # 优先选择包含完整关键文本且最短的列（通常是最匹配的）
                                # 计算每个匹配列的相似度（包含关键文本的长度比例）
                                scores <- sapply(matching_cols, function(col) {
                                    col_trimmed <- trimws(col)
                                    if (grepl(item_key, col_trimmed, fixed = TRUE)) {
                                        return(nchar(item_key) / nchar(col_trimmed))
                                    }
                                    return(0)
                                })
                                best_match_idx <- which.max(scores)
                                dat_col <- matching_cols[best_match_idx]
                                warning(paste("第", i, "行：题目", item, "使用模糊匹配找到列名：", dat_col))
                            } else {
                                # 方法2：如果方法1失败，尝试提取"--"后面的所有内容
                                item_suffix <- sub("^.*--", "", item)
                                item_suffix <- trimws(item_suffix)
                                matching_cols <- colnames(dat)[grepl(item_suffix, dat_cols_trimmed, fixed = TRUE)]
                                
                                if (length(matching_cols) > 0) {
                                    # 如果需要使用处理前的数据，优先选择带"_处理前"后缀的列
                                    if (use_before_processing) {
                                        matching_cols_before <- matching_cols[grepl("_处理前$", matching_cols)]
                                        if (length(matching_cols_before) > 0) {
                                            matching_cols <- matching_cols_before
                                        }
                                    }
                                    # 选择最短的匹配
                                    dat_col <- matching_cols[which.min(nchar(dat_cols_trimmed[matching_cols]))][1]
                                    warning(paste("第", i, "行：题目", item, "使用模糊匹配找到列名：", dat_col))
                                } else {
                                    # 方法3：尝试只匹配题目的核心部分（去掉标点符号和常见词汇）
                                    # 提取题目文本中的关键词（至少3个字符）
                                    item_words <- strsplit(item_key, "[，。、！？；：,.\\(\\)（）\\s]+")[[1]]
                                    item_words <- item_words[nchar(item_words) >= 3]
                                    
                                    if (length(item_words) > 0) {
                                        # 收集所有包含关键词的列
                                        all_matching_cols <- c()
                                        for (word in item_words) {
                                            matching_cols <- colnames(dat)[grepl(word, dat_cols_trimmed, fixed = TRUE)]
                                            all_matching_cols <- c(all_matching_cols, matching_cols)
                                        }
                                        all_matching_cols <- unique(all_matching_cols)
                                        
                                        if (length(all_matching_cols) > 0) {
                                            # 如果需要使用处理前的数据，优先选择带"_处理前"后缀的列
                                            if (use_before_processing) {
                                                matching_cols_before <- all_matching_cols[grepl("_处理前$", all_matching_cols)]
                                                if (length(matching_cols_before) > 0) {
                                                    all_matching_cols <- matching_cols_before
                                                }
                                            }
                                            
                                            # 选择包含最多关键词的列
                                            best_col <- NULL
                                            best_score <- 0
                                            for (col in all_matching_cols) {
                                                score <- sum(sapply(item_words, function(w) grepl(w, trimws(col), fixed = TRUE)))
                                                if (score > best_score) {
                                                    best_score <- score
                                                    best_col <- col
                                                }
                                            }
                                            if (!is.null(best_col)) {
                                                dat_col <- best_col
                                                warning(paste("第", i, "行：题目", item, "使用关键词匹配找到列名：", dat_col))
                                            } else {
                                                warning(paste("第", i, "行：未找到变量", dat_col, "（关键词匹配失败）"))
                                                next
                                            }
                                        } else {
                                            warning(paste("第", i, "行：未找到变量", dat_col, "（尝试所有匹配方法都失败）"))
                                            next
                                        }
                                    } else {
                                        warning(paste("第", i, "行：未找到变量", dat_col, "（无法提取关键词）"))
                                        next
                                    }
                                }
                            }
                        } else {
                            warning(paste("第", i, "行：未找到变量", dat_col, "（无法提取关键文本）"))
                            next
                        }
                    } else {
                        warning(paste("第", i, "行：未找到变量", dat_col))
                        next
                    }
                }
                
                # 获取选项文本（应该已经在分组时获取，但为了安全再次获取）
                options_str <- item_row$选项
                if (is.na(options_str) || options_str == "") {
                    warning(paste("第", i, "行：题目", item, "的选项为空"))
                    next
                }
                
                options <- strsplit(options_str, "//C//", fixed = TRUE)[[1]]
                options <- trimws(options)
                
                # 处理题目文本：只保留"--"、一个数字位、一个"."之后的内容
                # 兼容不同前缀数字的情况（如37、38、39开头）
                item_text <- item
                if (grepl("--", item_text, fixed = TRUE)) {
                    # 方法1：用"--"分割，取最后一部分（兼容多个"--"的情况）
                    parts <- strsplit(item_text, "--", fixed = TRUE)[[1]]
                    if (length(parts) >= 2) {
                        # 从第二部分开始查找符合"数字."格式的部分
                        for (j in 2:length(parts)) {
                            part <- trimws(parts[j])
                            if (grepl("^[0-9]+\\.", part)) {
                                item_text <- sub("^[0-9]+\\.", "", part)
                                item_text <- trimws(item_text)
                                break
                            }
                        }
                    }
                    
                    # 方法2：如果方法1没提取到，使用正则表达式直接提取"--数字.题目文本"
                    if (item_text == item) {
                        match_result <- regmatches(item_text, regexpr("--[0-9]+\\.(.+)", item_text))
                        if (length(match_result) > 0) {
                            item_text <- sub("^--[0-9]+\\.", "", match_result[1])
                            item_text <- trimws(item_text)
                        }
                    }
                    
                    # 方法3：如果还是没提取到，尝试提取最后一个"--"后面的内容
                    if (item_text == item && length(parts) >= 2) {
                        last_part <- trimws(parts[length(parts)])
                        if (grepl("^[0-9]+\\.", last_part)) {
                            item_text <- sub("^[0-9]+\\.", "", last_part)
                            item_text <- trimws(item_text)
                        } else {
                            # 如果没有数字前缀，直接使用最后一部分
                            item_text <- last_part
                        }
                    }
                }
                
                # 最后清理：如果仍然有数字和点开头，或者特殊符号结尾，则去掉
                # 去掉开头的数字和点（如"52.xxx"）
                if (grepl("^[0-9]+\\.", item_text)) {
                    item_text <- sub("^[0-9]+\\.", "", item_text)
                    item_text <- trimws(item_text)
                }
                
                # 去掉结尾的特殊符号（如"-"、"、"等）
                # 匹配结尾的特殊符号：-、,、，、。、；、:、：等
                item_text <- sub("[-,\\s，。；:：]+$", "", item_text)
                item_text <- trimws(item_text)
                
                # 计算每个选项的占比
                item_data <- dat[[dat_col]]
                n_total <- sum(!is.na(item_data))
                
                if (n_total == 0) {
                    next
                }
                
                # 创建行数据（题目文本始终显示）
                row_data <- data.frame(
                    题目 = item_text,
                    stringsAsFactors = FALSE
                )
                
                # 为每个选项添加列（值加%符号）
                for (opt_idx in seq_along(options)) {
                    opt_text <- options[opt_idx]
                    # 计算选择该选项的人数占比
                    n_selected <- sum(item_data == opt_idx, na.rm = TRUE)
                    pct <- (n_selected / n_total) * 100
                    row_data[[opt_text]] <- paste0(round(pct, 1), "%")
                }
                
                # 确保列的顺序一致
                row_data <- row_data[, c("题目", group_options), drop = FALSE]
                
                group_table <- rbind(group_table, row_data)
            }
            
            # 检查该组是否有有效数据
            if (nrow(group_table) > 0) {
                result_tables[[length(result_tables) + 1]] <- group_table
            }
        }
        
        # 检查是否有有效数据
        if (length(result_tables) == 0) {
            warning(paste("第", i, "行：table_items函数未生成任何数据，可能所有题目都未找到对应的列或没有有效数据"))
            return(NULL)
        }
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        for (table_idx in seq_along(result_tables)) {
            write.csv(result_tables[[table_idx]], 
                     paste0(table_path, "/", i, "_6_table_items_", table_idx, ".csv"), 
                     row.names = FALSE, fileEncoding = "UTF-8")
        }
        
        # 如果只有一个表格，直接返回；如果有多个表格，返回包含tables字段的列表
        if (length(result_tables) == 1) {
            return(result_tables[[1]])
        } else {
            return(list(tables = result_tables))
        }
    }, error = function(e) {
        warning(paste("第", i, "行：table_items函数执行失败：", e$message))
        return(NULL)
    })
}

# 6.5. table_dims_choice_percent函数
generate_table_dims_choice_percent <- function(dat, index_report_row, index_item, i, color_palette) {
    tryCatch({
        # 获取报告维度
        dim <- index_report_row$报告维度
        if (is.na(dim) || dim == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 获取交叉或分类变量
        cross_var <- index_report_row$交叉或分类变量
        if (is.na(cross_var) || cross_var == "") {
            warning(paste("第", i, "行：交叉或分类变量为空"))
            return(NULL)
        }
        
        # 确定交叉变量的列名
        if (cross_var %in% basic_vars) {
            cross_col <- cross_var
        } else {
            cross_col <- paste0(cross_var, "_Class")
        }
        
        if (!cross_col %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到交叉变量", cross_col))
            return(NULL)
        }
        
        # 根据数据表对应过滤index_item
        index_item_filtered <- filter_index_item_by_data_table(index_item, index_report_row)
        
        # 在index_item中找到该维度的所有题目列名
        # 首先在"报告维度"列中查找
        items <- index_item_filtered %>%
            filter(报告维度 == dim) %>%
            pull(题目列名)
        items <- items[!is.na(items)]
        
        # 如果找不到，则在"子维度"列中查找
        if (length(items) == 0 && "子维度" %in% colnames(index_item_filtered)) {
            items <- index_item_filtered %>%
                filter(子维度 == dim) %>%
                pull(题目列名)
            items <- items[!is.na(items)]
        }
        
        if (length(items) == 0) {
            warning(paste("第", i, "行：维度", dim, "未找到题目（在报告维度和子维度中都未找到）"))
            return(NULL)
        }
        
        # 收集所有题目的选项（假设所有题目的选项相同）
        all_options <- c()
        for (item in items) {
            item_row <- index_item_filtered %>% filter(题目列名 == item) %>% slice(1)
            if (nrow(item_row) > 0) {
                options_str <- item_row$选项
                if (!is.na(options_str) && options_str != "") {
                    options <- strsplit(options_str, "//C//", fixed = TRUE)[[1]]
                    options <- trimws(options)
                    all_options <- unique(c(all_options, options))
                }
            }
        }
        
        if (length(all_options) == 0) {
            warning(paste("第", i, "行：维度", dim, "的题目没有选项"))
            return(NULL)
        }
        
        # 获取交叉变量的所有类别
        if (is.factor(dat[[cross_col]])) {
            cross_categories <- levels(dat[[cross_col]])
            cross_categories <- cross_categories[cross_categories %in% unique(dat[[cross_col]])]
        } else {
            cross_categories <- unique(dat[[cross_col]])
            cross_categories <- cross_categories[!is.na(cross_categories)]
        }
        
        # 如果交叉变量是"区市"，添加"青岛市"总体，并放在最前面
        if (cross_var == "区市") {
            cross_categories <- c("青岛市", cross_categories)
        }
        
        # 初始化结果表格
        result_table <- data.frame(
            分类 = character(),
            stringsAsFactors = FALSE
        )
        for (opt in all_options) {
            result_table[[opt]] <- numeric()
        }
        
        # 对每个分类计算各选项的人题数量占比
        for (category in cross_categories) {
            # 确定数据子集
            if (category == "青岛市") {
                # 总体：使用所有数据
                dat_subset <- dat
            } else {
                # 特定类别：筛选该类别的数据
                dat_subset <- dat[dat[[cross_col]] == category & !is.na(dat[[cross_col]]), ]
            }
            
            if (nrow(dat_subset) == 0) {
                next
            }
            
            # 初始化该分类的行数据
            row_data <- data.frame(分类 = category, stringsAsFactors = FALSE)
            
            # 对每个选项计算人题数量占比
            total_person_items <- 0  # 总人题数
            option_counts <- numeric(length(all_options))  # 每个选项的人题数
            names(option_counts) <- all_options
            
            # 遍历所有题目
            for (item in items) {
                # 获取该题目的选项
                item_row <- index_item_filtered %>% filter(题目列名 == item) %>% slice(1)
                if (nrow(item_row) == 0) {
                    next
                }
                options_str <- item_row$选项
                if (is.na(options_str) || options_str == "") {
                    next
                }
                item_options <- strsplit(options_str, "//C//", fixed = TRUE)[[1]]
                item_options <- trimws(item_options)
                
                # 确定dat中的列名
                dat_col <- item
                if (!dat_col %in% colnames(dat_subset)) {
                    # 尝试模糊匹配
                    matching_cols <- colnames(dat_subset)[grepl(item, colnames(dat_subset), fixed = TRUE)]
                    if (length(matching_cols) > 0) {
                        dat_col <- matching_cols[1]
                    } else {
                        next
                    }
                }
                
                # 获取该题目的有效数据
                item_data <- dat_subset[[dat_col]]
                valid_data <- item_data[!is.na(item_data)]
                
                if (length(valid_data) == 0) {
                    next
                }
                
                # 计算总人题数（有效数据数量）
                total_person_items <- total_person_items + length(valid_data)
                
                # 计算每个选项的人题数（根据该题目的选项顺序）
                for (opt_idx in seq_along(item_options)) {
                    opt_text <- item_options[opt_idx]
                    # 如果该选项在all_options中，统计选择该选项的人数
                    if (opt_text %in% all_options) {
                        n_selected <- sum(valid_data == opt_idx, na.rm = TRUE)
                        option_counts[opt_text] <- option_counts[opt_text] + n_selected
                    }
                }
            }
            
            # 计算占比
            if (total_person_items > 0) {
                for (opt in all_options) {
                    pct <- (option_counts[opt] / total_person_items) * 100
                    row_data[[opt]] <- round(pct, 1)
                }
            } else {
                for (opt in all_options) {
                    row_data[[opt]] <- 0
                }
            }
            
            # 确保列的顺序一致
            row_data <- row_data[, c("分类", all_options), drop = FALSE]
            result_table <- rbind(result_table, row_data)
        }
        
        # 检查是否有有效数据
        if (nrow(result_table) == 0) {
            warning(paste("第", i, "行：table_dims_choice_percent函数未生成任何数据"))
            return(NULL)
        }
        
        # 将数值列格式化为带%符号的字符串
        for (opt in all_options) {
            result_table[[opt]] <- paste0(round(result_table[[opt]], 1), "%")
        }
        
        # 如果交叉变量是"区市"，确保"青岛市"在最上面
        if (cross_var == "区市" && "青岛市" %in% result_table$分类) {
            # 将"青岛市"行移到最前面
            qingdao_row <- result_table[result_table$分类 == "青岛市", ]
            other_rows <- result_table[result_table$分类 != "青岛市", ]
            result_table <- rbind(qingdao_row, other_rows)
        }
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_6.5_table_dims_choice_percent.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        return(result_table)
    }, error = function(e) {
        warning(paste("第", i, "行：table_dims_choice_percent函数执行失败：", e$message))
        return(NULL)
    })
}

# 7. table_items_score函数
generate_table_items_score <- function(dat, index_report_row, index_item, i, color_palette) {
    tryCatch({
        # 获取报告维度
        dim <- index_report_row$报告维度
        if (is.na(dim) || dim == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 根据数据表对应过滤index_item
        index_item_filtered <- filter_index_item_by_data_table(index_item, index_report_row)
        
        # 在index_item中找到该维度的所有题目列名
        # 首先在"报告维度"列中查找
        items <- index_item_filtered %>%
            filter(报告维度 == dim) %>%
            pull(题目列名)
        items <- items[!is.na(items)]
        
        # 如果找不到，则在"子维度"列中查找
        if (length(items) == 0 && "子维度" %in% colnames(index_item_filtered)) {
            items <- index_item_filtered %>%
                filter(子维度 == dim) %>%
                pull(题目列名)
            items <- items[!is.na(items)]
        }
        
        if (length(items) == 0) {
            warning(paste("第", i, "行：维度", dim, "未找到题目（在报告维度和子维度中都未找到）"))
            return(NULL)
        }
        
        # 初始化结果表格
        result_table <- data.frame(
            题目 = character(),
            平均分 = numeric(),
            stringsAsFactors = FALSE
        )
        
        # 对每个题目计算平均分
        for (item in items) {
            # 提取题目文本：只取"--{数字}."后面的内容
            # 使用正则表达式匹配 "--数字." 后面的内容
            item_text <- item
            if (grepl("--[0-9]+\\.", item)) {
                # 提取 "--数字." 后面的内容
                item_text <- sub("^.*--[0-9]+\\.", "", item)
                item_text <- trimws(item_text)
            }
            
            # 确定dat中的列名
            dat_col <- item
            if (!dat_col %in% colnames(dat)) {
                # 尝试模糊匹配：提取"--数字.题目文本"部分
                if (grepl("--", item, fixed = TRUE)) {
                    match_result <- regmatches(item, regexpr("--[0-9]+\\.(.+)", item))
                    if (length(match_result) > 0) {
                        item_key <- sub("^--[0-9]+\\.", "", match_result[1])
                        item_key <- trimws(item_key)
                        
                        # 在dat的列名中查找包含这个关键文本的列
                        dat_cols_trimmed <- trimws(colnames(dat))
                        matching_cols <- colnames(dat)[grepl(item_key, dat_cols_trimmed, fixed = TRUE)]
                        
                        if (length(matching_cols) > 0) {
                            # 选择最短的匹配（通常是最匹配的）
                            dat_col <- matching_cols[which.min(nchar(matching_cols))][1]
                        } else {
                            warning(paste("第", i, "行：未找到题目", item, "对应的数据列"))
                            next
                        }
                    } else {
                        warning(paste("第", i, "行：无法解析题目", item))
                        next
                    }
                } else {
                    warning(paste("第", i, "行：未找到题目", item, "对应的数据列"))
                    next
                }
            }
            
            # 计算该题目的平均分
            if (dat_col %in% colnames(dat)) {
                mean_score <- mean(dat[[dat_col]], na.rm = TRUE)
                # 保留1位小数
                mean_score <- round(mean_score, 2)
                
                # 添加到结果表格
                result_table <- rbind(result_table, data.frame(
                    题目 = item_text,
                    平均分 = mean_score,
                    stringsAsFactors = FALSE
                ))
            }
        }
        
        if (nrow(result_table) == 0) {
            warning(paste("第", i, "行：未找到任何有效的题目数据"))
            return(NULL)
        }
        
        # 0114，去掉均分的计算
        # # 计算维度均分（所有题目的平均分的平均值）
        # dim_mean_score <- mean(result_table$平均分, na.rm = TRUE)
        # dim_mean_score <- round(dim_mean_score, 2)
        
        # 在表格最后添加一行维度均分
        # result_table <- rbind(result_table, data.frame(
        #     题目 = "维度均分",
        #     平均分 = dim_mean_score,
        #     stringsAsFactors = FALSE
        # ))
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_table_items_score.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 将维度均分作为属性保存，以便后续使用
        # attr(result_table, "dim_mean_score") <- dim_mean_score
        
        return(result_table)
    }, error = function(e) {
        warning(paste("第", i, "行：table_items_score函数执行失败：", e$message))
        return(NULL)
    })
}

# 7.1 simple_bar_items_score函数（题目均分计算逻辑与 table_items_score 相同，输出横向条形图）
generate_simple_bar_items_score <- function(dat, index_report_row, index_item, i, color_palette) {
    tryCatch({
        dim <- index_report_row$报告维度
        if (is.na(dim) || dim == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        index_item_filtered <- filter_index_item_by_data_table(index_item, index_report_row)
        
        items <- index_item_filtered %>%
            filter(报告维度 == dim) %>%
            pull(题目列名)
        items <- items[!is.na(items)]
        
        if (length(items) == 0 && "子维度" %in% colnames(index_item_filtered)) {
            items <- index_item_filtered %>%
                filter(子维度 == dim) %>%
                pull(题目列名)
            items <- items[!is.na(items)]
        }
        
        if (length(items) == 0) {
            warning(paste("第", i, "行：维度", dim, "未找到题目（在报告维度和子维度中都未找到）"))
            return(NULL)
        }
        
        result_table <- data.frame(
            题目 = character(),
            平均分 = numeric(),
            stringsAsFactors = FALSE
        )
        dat_cols_used <- character()
        
        for (item in items) {
            item_text <- item
            if (grepl("--[0-9]+\\.", item)) {
                item_text <- sub("^.*--[0-9]+\\.", "", item)
                item_text <- trimws(item_text)
            }
            
            dat_col <- item
            if (!dat_col %in% colnames(dat)) {
                if (grepl("--", item, fixed = TRUE)) {
                    match_result <- regmatches(item, regexpr("--[0-9]+\\.(.+)", item))
                    if (length(match_result) > 0) {
                        item_key <- sub("^--[0-9]+\\.", "", match_result[1])
                        item_key <- trimws(item_key)
                        
                        dat_cols_trimmed <- trimws(colnames(dat))
                        matching_cols <- colnames(dat)[grepl(item_key, dat_cols_trimmed, fixed = TRUE)]
                        
                        if (length(matching_cols) > 0) {
                            dat_col <- matching_cols[which.min(nchar(matching_cols))][1]
                        } else {
                            warning(paste("第", i, "行：未找到题目", item, "对应的数据列"))
                            next
                        }
                    } else {
                        warning(paste("第", i, "行：无法解析题目", item))
                        next
                    }
                } else {
                    warning(paste("第", i, "行：未找到题目", item, "对应的数据列"))
                    next
                }
            }
            
            if (dat_col %in% colnames(dat)) {
                mean_score <- mean(dat[[dat_col]], na.rm = TRUE)
                mean_score <- round(mean_score, 2)
                
                result_table <- rbind(result_table, data.frame(
                    题目 = item_text,
                    平均分 = mean_score,
                    stringsAsFactors = FALSE
                ))
                dat_cols_used <- c(dat_cols_used, dat_col)
            }
        }
        
        if (nrow(result_table) == 0) {
            warning(paste("第", i, "行：未找到任何有效的题目数据"))
            return(NULL)
        }
        
        all_vals <- unlist(lapply(dat_cols_used, function(cc) dat[[cc]]), use.names = FALSE)
        dim_all_mean <- mean(all_vals, na.rm = TRUE)
        attr(result_table, "dim_all_items_person_mean") <- dim_all_mean
        
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_simple_bar_items_score.csv"),
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        result_table$题目_格式化 <- sapply(result_table$题目, function(label) {
            if (nchar(label) > 21) {
                chars <- strsplit(label, "")[[1]]
                n <- length(chars)
                result <- ""
                for (ii in seq(1, n, by = 21)) {
                    end_idx <- min(ii + 19, n)
                    segment <- paste(chars[ii:end_idx], collapse = "")
                    if (ii == 1) {
                        result <- segment
                    } else {
                        result <- paste0(result, "\n", segment)
                    }
                }
                return(result)
            } else {
                return(label)
            }
        })
        
        n_bars <- nrow(result_table)
        plot_height <- max(2.5, n_bars * 0.3)
        
        max_val <- max(result_table$平均分, na.rm = TRUE)
        if (max_val <= 1) {
            x_breaks <- seq(0, 1, by = 0.1)
            x_max <- 1.15
        } else if (max_val <= 10) {
            x_breaks <- seq(0, ceiling(max_val), by = 1)
            x_max <- max(max_val * 1.15, ceiling(max_val) + 1)
        } else {
            x_breaks <- seq(0, ceiling(max_val / 10) * 10, by = 10)
            x_max <- max(max_val * 1.15, ceiling(max_val / 10) * 10 + 10)
        }
        x_label_format <- function(x) as.character(round(x, 1))
        label_format <- function(x) formatC(round(as.numeric(x), 2), format = "f", digits = 2)
        
        y_label_mapping <- setNames(result_table$题目_格式化, result_table$题目)
        
        p <- ggplot(result_table, aes(x = 平均分, y = reorder(题目, 平均分))) +
            geom_bar(stat = "identity", fill = color_palette$color_1[1], width = 0.4) +
            geom_text(aes(label = label_format(平均分)), hjust = -0.1, size = 3) +
            labs(caption = ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题),
                 x = "", y = "") +
            scale_x_continuous(labels = x_label_format, breaks = x_breaks, limits = c(0, x_max), expand = c(0, 0)) +
            scale_y_discrete(labels = function(x) y_label_mapping[x]) +
            theme_minimal() +
            theme(legend.position = "none",
                  plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                  plot.caption.position = "plot",
                  axis.text.y = element_text(angle = 0),
                  panel.grid = element_blank(),
                  axis.line = element_line(color = "black"))
        
        attr(p, "plot_height") <- plot_height
        
        dim_name_txt <- ifelse(is.na(index_report_row$报告维度) || index_report_row$报告维度 == "", "该维度", index_report_row$报告维度)
        grand_txt <- attr(result_table, "dim_all_items_person_mean")
        if (is.null(grand_txt) || is.na(grand_txt)) {
            grand_txt <- mean(result_table$平均分, na.rm = TRUE)
        }
        num_str <- formatC(round(as.numeric(grand_txt), 2), format = "f", digits = 2)
        text_out <- paste0(dim_name_txt, "的平均值是", num_str, "。")
        
        return(list(table = result_table, plot = p, text = text_out))
    }, error = function(e) {
        warning(paste("第", i, "行：simple_bar_items_score函数执行失败：", e$message))
        return(NULL)
    })
}

# 7.5. calculate_score_rate_by_analysis_var函数（按分析变量计算得分率表格）
calculate_score_rate_by_analysis_var <- function(dat, item_infor, analysis_var) {
    tryCatch({
        # 检查必要的列是否存在
        if (!analysis_var %in% colnames(item_infor)) {
            stop(paste("分析变量", analysis_var, "不在item_infor中"))
        }
        
        if (!"小题号" %in% colnames(item_infor)) {
            stop("item_infor中缺少'小题号'列")
        }
        
        if (!"小题分满分" %in% colnames(item_infor)) {
            stop("item_infor中缺少'小题分满分'列")
        }
        
        if (!"区市" %in% colnames(dat)) {
            stop("dat中缺少'区市'列")
        }
        
        # 获取分析变量的所有唯一值
        analysis_values <- unique(item_infor[[analysis_var]])
        analysis_values <- analysis_values[!is.na(analysis_values)]
        
        if (length(analysis_values) == 0) {
            stop(paste("分析变量", analysis_var, "没有有效值"))
        }
        
        # 获取区市的所有唯一值
        qu_shi_values <- levels(dat$区市)
        
        # 初始化结果表格：行为区市+青岛市，列为分析变量的值
        result_table <- data.frame(
            区市 = c("青岛市", qu_shi_values),
            stringsAsFactors = FALSE
        )
        
        # 预先提取dat中所有的小题列（避免重复查找）
        dat_cols <- colnames(dat)
        
        # 为每个分析变量的值添加列
        for (analysis_val in analysis_values) {
            # 找到该分析变量值对应的所有小题号
            item_rows <- item_infor[item_infor[[analysis_var]] == analysis_val & !is.na(item_infor[[analysis_var]]), ]
            
            if (nrow(item_rows) == 0) {
                # 如果没有对应的小题，该列的得分率设为NA
                result_table[[as.character(analysis_val)]] <- NA
                next
            }
            
            # 获取小题号和满分值
            item_numbers <- item_rows$小题号
            item_full_scores <- item_rows$小题分满分
            
            # 将小题号转为character，用于在dat中查找列
            item_numbers_char <- as.character(item_numbers)
            
            # 检查dat中是否存在这些小题列
            existing_item_cols <- item_numbers_char[item_numbers_char %in% dat_cols]
            
            if (length(existing_item_cols) == 0) {
                result_table[[as.character(analysis_val)]] <- NA
                next
            }
            
            # 计算满分总和（只计算dat中实际存在的小题列对应的满分值）
            # 创建小题号到满分的映射
            item_score_map <- setNames(item_full_scores, item_numbers_char)
            # 只计算existing_item_cols对应的满分值
            total_full_score <- sum(item_score_map[existing_item_cols], na.rm = TRUE)
            
            if (total_full_score == 0) {
                result_table[[as.character(analysis_val)]] <- NA
                next
            }
            
            # 预先提取需要的小题列数据（向量化操作，避免循环）
            item_data <- dat[, existing_item_cols, drop = FALSE]
            # 将缺失值替换为0（向量化操作）
            item_data[is.na(item_data)] <- 0
            # 转换为数值矩阵（如果还不是）
            item_data <- as.data.frame(lapply(item_data, as.numeric))
            
            # 计算每个人的得分（使用rowSums向量化操作）
            person_scores_all <- rowSums(item_data, na.rm = TRUE)
            
            # 计算每个区市的得分率（向量化操作）
            score_rates <- numeric(nrow(result_table))
            
            for (i in seq_len(nrow(result_table))) {
                qu_shi <- result_table$区市[i]
                
                if (qu_shi == "青岛市") {
                    # 青岛市：使用全部数据
                    person_scores <- person_scores_all
                } else {
                    # 各区市：使用对应区市的数据（向量化筛选）
                    qu_shi_mask <- dat$区市 == qu_shi & !is.na(dat$区市)
                    if (sum(qu_shi_mask) == 0) {
                        score_rates[i] <- NA
                        next
                    }
                    person_scores <- person_scores_all[qu_shi_mask]
                }
                
                # 计算平均得分率
                avg_score <- mean(person_scores, na.rm = TRUE)
                score_rate <- avg_score / total_full_score
                score_rates[i] <- score_rate
            }
            
            result_table[[as.character(analysis_val)]] <- score_rates
        }
        
        return(result_table)
    }, error = function(e) {
        warning(paste("calculate_score_rate_by_analysis_var函数执行失败：", e$message))
        return(NULL)
    })
}

# 7.6. calculate_knowledge_point_score_rate函数（计算各知识点得分率表格）
calculate_knowledge_point_score_rate <- function(dat, item_infor, knowledge_var = "考查知识点（知识层级三）（小题知识点）") {
    tryCatch({
        # 检查必要的列是否存在
        if (!knowledge_var %in% colnames(item_infor)) {
            stop(paste("知识点变量", knowledge_var, "不在item_infor中"))
        }
        
        if (!"小题号" %in% colnames(item_infor)) {
            stop("item_infor中缺少'小题号'列")
        }
        
        if (!"小题分满分" %in% colnames(item_infor)) {
            stop("item_infor中缺少'小题分满分'列")
        }
        
        if (!"题型" %in% colnames(item_infor)) {
            stop("item_infor中缺少'题型'列")
        }
        
        # 预先提取dat中所有的小题列（避免重复查找）
        dat_cols <- colnames(dat)
        
        # 获取知识点的所有唯一值
        knowledge_points <- unique(item_infor[[knowledge_var]])
        knowledge_points <- knowledge_points[!is.na(knowledge_points)]
        
        if (length(knowledge_points) == 0) {
            stop(paste("知识点变量", knowledge_var, "没有有效值"))
        }
        
        # 初始化结果表格
        result_table <- data.frame(
            题号 = character(),
            分值 = character(),
            核心考点 = character(),
            知识点得分率 = numeric(),
            题型 = character(),
            stringsAsFactors = FALSE
        )
        
        # 为每个知识点计算得分率
        for (knowledge_point in knowledge_points) {
            # 找到该知识点对应的所有小题
            item_rows <- item_infor[item_infor[[knowledge_var]] == knowledge_point & !is.na(item_infor[[knowledge_var]]), ]
            
            if (nrow(item_rows) == 0) {
                next
            }
            
            # 获取小题号、满分值和题型
            item_numbers <- item_rows$小题号
            item_full_scores <- item_rows$小题分满分
            item_types <- item_rows$题型
            
            # 将小题号转为character，用于在dat中查找列
            item_numbers_char <- as.character(item_numbers)
            
            # 检查dat中是否存在这些小题列
            existing_item_cols <- item_numbers_char[item_numbers_char %in% dat_cols]
            
            if (length(existing_item_cols) == 0) {
                # 如果没有对应的列，跳过
                next
            }
            
            # 计算满分总和（只计算dat中实际存在的小题列对应的满分值）
            item_score_map <- setNames(item_full_scores, item_numbers_char)
            total_full_score <- sum(item_score_map[existing_item_cols], na.rm = TRUE)
            
            if (total_full_score == 0) {
                next
            }
            
            # 预先提取需要的小题列数据（向量化操作）
            item_data <- dat[, existing_item_cols, drop = FALSE]
            # 将缺失值替换为0（向量化操作）
            item_data[is.na(item_data)] <- 0
            # 转换为数值矩阵
            item_data <- as.data.frame(lapply(item_data, as.numeric))
            
            # 计算每个人的得分（使用rowSums向量化操作）
            person_scores_all <- rowSums(item_data, na.rm = TRUE)
            
            # 计算总体平均得分率
            avg_score <- mean(person_scores_all, na.rm = TRUE)
            score_rate <- avg_score / total_full_score
            
            # 准备题号字符串（多个用中文顿号分割）
            item_numbers_str <- paste(item_numbers, collapse = "、")
            
            # 准备分值字符串（多个用中文顿号分割）
            item_scores_str <- paste(item_full_scores, collapse = "、")
            
            # 获取题型（如果有多个，取第一个，或者用顿号连接所有唯一值）
            item_types_unique <- unique(item_types)
            item_types_unique <- item_types_unique[!is.na(item_types_unique)]
            item_type_str <- if (length(item_types_unique) > 0) {
                paste(item_types_unique, collapse = "、")
            } else {
                NA_character_
            }
            
            # 添加到结果表格
            result_table <- rbind(result_table, data.frame(
                题号 = item_numbers_str,
                分值 = item_scores_str,
                核心考点 = knowledge_point,
                知识点得分率 = score_rate,
                题型 = item_type_str,
                stringsAsFactors = FALSE
            ))
        }
        
        # 按知识点得分率从大到小排序
        result_table <- result_table[order(result_table$知识点得分率, decreasing = TRUE), ]
        
        # 将知识点得分率转为百分数形式，加%符号
        result_table$知识点得分率 <- paste0(round(result_table$知识点得分率 * 100, 2), "%")
        
        return(result_table)
    }, error = function(e) {
        warning(paste("calculate_knowledge_point_score_rate函数执行失败：", e$message))
        return(NULL)
    })
}

# 7.7. calculate_school_variance_ratio函数（计算校际差异占总体差异的比例）
calculate_school_variance_ratio <- function(dat, score_var = "量尺分", school_var = "学校", qu_shi_var = "区市") {
    tryCatch({
        # 检查必要的包
        if (!requireNamespace("lme4", quietly = TRUE)) {
            stop("需要安装lme4包：install.packages('lme4')")
        }
        
        # 检查必要的列是否存在
        if (!score_var %in% colnames(dat)) {
            stop(paste("学业成绩变量", score_var, "不在dat中"))
        }
        
        if (!school_var %in% colnames(dat)) {
            stop(paste("学校变量", school_var, "不在dat中"))
        }
        
        if (!qu_shi_var %in% colnames(dat)) {
            stop(paste("区市变量", qu_shi_var, "不在dat中"))
        }
        
        # 获取区市的所有唯一值
        if (is.factor(dat[[qu_shi_var]])) {
            qu_shi_values <- levels(dat[[qu_shi_var]])
            # 只保留实际存在的值
            qu_shi_values <- qu_shi_values[qu_shi_values %in% unique(dat[[qu_shi_var]])]
        } else {
            qu_shi_values <- unique(dat[[qu_shi_var]])
            qu_shi_values <- qu_shi_values[!is.na(qu_shi_values)]
        }
        
        # 初始化结果表格（确保所有列长度一致）
        n_rows <- 1 + length(qu_shi_values)  # 青岛市 + 各区市
        result_table <- data.frame(
            区市 = c("青岛市", qu_shi_values),
            学业成绩 = numeric(n_rows),
            校际差异比例 = numeric(n_rows),
            stringsAsFactors = FALSE
        )
        
        # 计算每个区市的校际差异比例
        for (i in seq_len(nrow(result_table))) {
            qu_shi <- result_table$区市[i]
            
            if (qu_shi == "青岛市") {
                # 青岛市：使用全部数据
                dat_subset <- dat[!is.na(dat[[score_var]]) & !is.na(dat[[school_var]]), ]
            } else {
                # 各区市：使用对应区市的数据
                dat_subset <- dat[dat[[qu_shi_var]] == qu_shi & !is.na(dat[[qu_shi_var]]) & 
                                  !is.na(dat[[score_var]]) & !is.na(dat[[school_var]]), ]
            }
            
            if (nrow(dat_subset) == 0 || length(unique(dat_subset[[school_var]])) < 2) {
                result_table$学业成绩[i] <- NA
                result_table$校际差异比例[i] <- NA
                next
            }
            
            # 计算平均学业成绩
            avg_score <- mean(dat_subset[[score_var]], na.rm = TRUE)
            result_table$学业成绩[i] <- avg_score
            
            # 拟合HLM模型（空模型，只有截距和学校随机效应）
            tryCatch({
                model <- lme4::lmer(as.formula(paste(score_var, "~ 1 + (1 |", school_var, ")")), 
                                   data = dat_subset)
                
                # 提取方差成分
                var_components <- as.data.frame(lme4::VarCorr(model))
                # 学校层方差
                school_var_val <- var_components$vcov[var_components$grp == school_var]
                # 残差方差（学生层方差）
                residual_var_val <- var_components$vcov[var_components$grp == "Residual"]
                # 总方差
                total_var_val <- school_var_val + residual_var_val
                
                # 计算校际差异占总体差异的比例（ICC）
                icc <- school_var_val / total_var_val
                result_table$校际差异比例[i] <- icc
            }, error = function(e) {
                warning(paste("区市", qu_shi, "的HLM模型拟合失败：", e$message))
                result_table$校际差异比例[i] <- NA
            })
        }
        
        return(result_table)
    }, error = function(e) {
        warning(paste("calculate_school_variance_ratio函数执行失败：", e$message))
        return(NULL)
    })
}

# 7.8. generate_school_variance_scatter函数（校际差异散点图）
generate_school_variance_scatter <- function(variance_table, color_palette, title = "校际差异散点图") {
    tryCatch({
        if (is.null(variance_table) || nrow(variance_table) == 0) {
            warning("variance_table为空")
            return(NULL)
        }
        
        # 移除缺失值
        plot_data <- variance_table[!is.na(variance_table$校际差异比例) & 
                                    !is.na(variance_table$学业成绩), ]
        
        if (nrow(plot_data) == 0) {
            warning("没有有效数据用于绘图")
            return(NULL)
        }
        
        # 区分青岛市和其他区市
        plot_data$is_qingdao <- plot_data$区市 == "青岛市"
        
        # 将校际差异比例转换为百分数（用于X轴）
        plot_data$校际差异比例_pct <- plot_data$校际差异比例 * 100
        
        # 计算坐标轴范围（拉宽一些，并确保包含参考线）
        x_min <- min(plot_data$校际差异比例_pct, na.rm = TRUE)
        x_max <- max(plot_data$校际差异比例_pct, na.rm = TRUE)
        x_range <- x_max - x_min
        # 确保包含参考线X=10和X=20
        x_limits <- c(max(0, min(x_min - x_range * 0.1, 0)), max(x_max + x_range * 0.1, 42))
        
        # Y轴范围写死为200-710
        y_limits <- c(200, 710)
        
        # 绘制散点图
        p <- ggplot(plot_data, aes(x = 校际差异比例_pct, y = 学业成绩)) +
            # 添加参考线（Y=400, Y=600, X=10, X=20）
            geom_hline(yintercept = 400, linetype = "dashed", color = "gray70", linewidth = 0.5) +
            geom_hline(yintercept = 600, linetype = "dashed", color = "gray70", linewidth = 0.5) +
            geom_vline(xintercept = 10, linetype = "dashed", color = "gray70", linewidth = 0.5) +
            geom_vline(xintercept = 20, linetype = "dashed", color = "gray70", linewidth = 0.5) +
            # 散点
            geom_point(aes(color = is_qingdao), size = 3.5, alpha = 0.7) +
            scale_color_manual(values = c("FALSE" = color_palette$color_1[1], 
                                         "TRUE" = color_palette$color_1_highlight_2[1]),
                              guide = "none") +
            # 标签
            geom_text(aes(label = 区市), hjust = 0.5, vjust = -0.5, size = 3) +
            # 四个象限的标注（左侧两处 x 取 x_limits[1]，与 x 轴左端对齐）
            annotate("text", x = x_limits[1],
                    y = y_limits[2] - (y_limits[2] - y_limits[1]) * 0.05,
                    label = "校际差异较小\n学业成绩较高", 
                    hjust = 0, vjust = 1, size = 4, color = "gray50") +
            annotate("text", x = x_limits[1],
                    y = y_limits[1] + (y_limits[2] - y_limits[1]) * 0.05,
                    label = "校际差异较小\n学业成绩较低", 
                    hjust = 0, vjust = 0, size = 4, color = "gray50") +
            annotate("text", x = x_limits[2] - (x_limits[2] - x_limits[1]) * 0.1, 
                    y = y_limits[2] - (y_limits[2] - y_limits[1]) * 0.05,
                    label = "校际差异较大\n学业成绩较高", 
                    hjust = 1, vjust = 1, size = 4, color = "gray50") +
            annotate("text", x = x_limits[2] - (x_limits[2] - x_limits[1]) * 0.1, 
                    y = y_limits[1] + (y_limits[2] - y_limits[1]) * 0.05,
                    label = "校际差异较大\n学业成绩较低", 
                    hjust = 1, vjust = 0, size = 4, color = "gray50") +
            labs(x = "",
                 y = "学业成绩",
                 caption = title) +
            scale_x_continuous(labels = function(x) paste0(x), 
                             breaks = seq(0, ceiling(x_limits[2]), by = 5),
                             limits = x_limits, expand = c(0, 0)) +
            scale_y_continuous(breaks = seq(floor(y_limits[1] / 50) * 50, 
                                          ceiling(y_limits[2] / 50) * 50, by = 50),
                             limits = y_limits, expand = c(0, 0)) +
            coord_cartesian(xlim = x_limits, ylim = y_limits, expand = FALSE) +
            theme_minimal() +
            theme(plot.title = element_blank(),
                  plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                  plot.caption.position = "plot",
                  axis.title = element_text(size = 12),
                  axis.text = element_text(size = 10),
                  panel.grid.minor = element_blank(),
                  panel.grid.major = element_line(color = "gray90", linewidth = 0.3),
                  axis.line = element_line(color = "black", linewidth = 0.5),
                  panel.background = element_rect(color = NA, fill = "white", linewidth = 0),
                  plot.background = element_rect(fill = "white", color = NA, linewidth = 0))
                  
        
        # 存储高度信息
        attr(p, "plot_height") <- 5
        
        return(list(table = variance_table, plot = p))
    }, error = function(e) {
        warning(paste("generate_school_variance_scatter函数执行失败：", e$message))
        return(NULL)
    })
}

# 7.9. calculate_school_mean_cv函数（计算每所学校的成绩均值和CV）
calculate_school_mean_cv <- function(dat, score_var = "量尺分", school_var = "学校", qu_shi_var = "区市") {
    tryCatch({
        # 检查必要的列是否存在
        if (!score_var %in% colnames(dat)) {
            stop(paste("学业成绩变量", score_var, "不在dat中"))
        }
        
        if (!school_var %in% colnames(dat)) {
            stop(paste("学校变量", school_var, "不在dat中"))
        }
        
        if (!qu_shi_var %in% colnames(dat)) {
            stop(paste("区市变量", qu_shi_var, "不在dat中"))
        }
        
        # 筛选有效数据
        dat_valid <- dat[!is.na(dat[[score_var]]) & !is.na(dat[[school_var]]) & 
                        !is.na(dat[[qu_shi_var]]), ]
        
        if (nrow(dat_valid) == 0) {
            stop("没有有效数据")
        }
        
        # 按学校分组计算均值和CV
        result_table <- dat_valid %>%
            group_by(.data[[school_var]], .data[[qu_shi_var]]) %>%
            summarise(
                成绩均值 = mean(.data[[score_var]], na.rm = TRUE),
                成绩标准差 = sd(.data[[score_var]], na.rm = TRUE),
                .groups = "drop"
            ) %>%
            mutate(
                校内差异 = ifelse(成绩均值 != 0, (成绩标准差 / 成绩均值) * 100, NA)
            ) %>%
            rename(学校 = .data[[school_var]], 区市 = .data[[qu_shi_var]])
        
        return(result_table)
    }, error = function(e) {
        warning(paste("calculate_school_mean_cv函数执行失败：", e$message))
        return(NULL)
    })
}

# 7.10. generate_school_cv_scatter函数（校内差异散点图）
generate_school_cv_scatter <- function(school_cv_table, color_palette, title = "校内差异散点图", color_by = "区市") {
    tryCatch({
        if (is.null(school_cv_table) || nrow(school_cv_table) == 0) {
            warning("school_cv_table为空")
            return(NULL)
        }
        
        # 移除缺失值
        plot_data <- school_cv_table[!is.na(school_cv_table$校内差异) & 
                                     !is.na(school_cv_table$成绩均值), ]
        
        if (nrow(plot_data) == 0) {
            warning("没有有效数据用于绘图")
            return(NULL)
        }
        
        # 检查color_by列是否存在
        if (!color_by %in% colnames(plot_data)) {
            warning(paste("color_by列", color_by, "不存在，使用默认值'区市'"))
            color_by <- "区市"
        }
        
        # 获取颜色列的所有唯一值（用于颜色映射）
        color_values <- unique(plot_data[[color_by]])
        color_values <- color_values[!is.na(color_values)]
        
        # 计算坐标轴范围（拉宽一些，并确保包含参考线）
        x_min <- min(plot_data$校内差异, na.rm = TRUE)
        x_max <- max(plot_data$校内差异, na.rm = TRUE)
        x_range <- x_max - x_min
        
        # 计算带边距的范围（添加10%的边距，但至少5个单位）
        margin <- max(x_range * 0.1, 5)
        x_min_with_margin <- max(0, x_min - margin)  # 确保最小值至少为0
        x_max_with_margin <- x_max + margin
        
        # 确保包含参考线X=10和X=20
        # 最小值：确保包含所有数据点和参考线10
        x_limit_min <- min(x_min_with_margin, 10)
        # 最大值：确保包含所有数据点和参考线20
        x_limit_max <- max(x_max_with_margin, 42)
        
        x_limits <- c(x_limit_min, x_limit_max)
        
        # Y轴范围：动态计算，确保包含所有数据点和参考线
        y_min <- min(plot_data$成绩均值, na.rm = TRUE)
        y_max <- max(plot_data$成绩均值, na.rm = TRUE)
        y_range <- y_max - y_min
        
        # 计算带边距的范围（添加10%的边距，但至少20个单位）
        y_margin <- max(y_range * 0.1, 20)
        y_min_with_margin <- y_min - y_margin
        y_max_with_margin <- y_max + y_margin
        
        # 确保包含参考线Y=400和Y=600
        # 最小值：确保包含所有数据点和参考线400
        y_limit_min <- min(y_min_with_margin, 200)
        # 最大值：确保包含所有数据点和参考线600
        y_limit_max <- max(y_max_with_margin, 710)
        
        y_limits <- c(y_limit_min, y_limit_max)
        
        # 获取颜色映射（为每个颜色值分配颜色）
        n_color <- length(color_values)
        if (n_color <= 11) {
            color_key <- paste0("color_", min(n_color, 11))
            if (color_key %in% names(color_palette)) {
                colors_vec <- color_palette[[color_key]][1:n_color]
            } else {
                colors_vec <- rep(color_palette$color_1[1], n_color)
            }
        } else {
            colors_vec <- rep(color_palette$color_1[1], n_color)
        }
        
        color_mapping <- setNames(colors_vec, color_values)
        
        # 少量散点时的标签（去掉“青岛市/青岛”字样）
        plot_data$学校_标签 <- gsub("青岛市|青岛", "", plot_data$学校)
        
        # 绘制散点图
        p <- ggplot(plot_data, aes(x = 校内差异, y = 成绩均值, color = .data[[color_by]])) +
            # 添加参考线（Y=400, Y=600, X=10, X=20）
            geom_hline(yintercept = 400, linetype = "dashed", color = "gray70", linewidth = 0.5) +
            geom_hline(yintercept = 600, linetype = "dashed", color = "gray70", linewidth = 0.5) +
            geom_vline(xintercept = 10, linetype = "dashed", color = "gray70", linewidth = 0.5) +
            geom_vline(xintercept = 20, linetype = "dashed", color = "gray70", linewidth = 0.5) +
            # 散点
            geom_point(size = 2.5, alpha = 0.7) +
            scale_color_manual(values = color_mapping, name = "") +
            # 四个象限的标注（左侧两处 x 取 x_limits[1]，与 x 轴左端对齐）
            annotate("text", x = x_limits[1],
                    y = y_limits[2] - (y_limits[2] - y_limits[1]) * 0.05,
                    label = "校内差异较小\n学业成绩较高", 
                    hjust = 0, vjust = 1, size = 4, color = "gray50") +
            annotate("text", x = x_limits[1],
                    y = y_limits[1] + (y_limits[2] - y_limits[1]) * 0.05,
                    label = "校内差异较小\n学业成绩较低", 
                    hjust = 0, vjust = 0, size = 4, color = "gray50") +
            annotate("text", x = x_limits[2] - (x_limits[2] - x_limits[1]) * 0.1, 
                    y = y_limits[2] - (y_limits[2] - y_limits[1]) * 0.05,
                    label = "校内差异较大\n学业成绩较高", 
                    hjust = 1, vjust = 1, size = 4, color = "gray50") +
            annotate("text", x = x_limits[2] - (x_limits[2] - x_limits[1]) * 0.1, 
                    y = y_limits[1] + (y_limits[2] - y_limits[1]) * 0.05,
                    label = "校内差异较大\n学业成绩较低", 
                    hjust = 1, vjust = 0, size = 4, color = "gray50") +
            labs(x = "",
                 y = "学业成绩",
                 caption = title) +
            scale_x_continuous(labels = function(x) paste0(x),
                             breaks = seq(0, ceiling(x_limits[2]), by = 5),
                             limits = x_limits, expand = c(0, 0)) +
            scale_y_continuous(breaks = seq(floor(y_limits[1] / 50) * 50, 
                                          ceiling(y_limits[2] / 50) * 50, by = 50),
                             expand = c(0, 0)) +
            coord_cartesian(xlim = x_limits, ylim = y_limits, expand = FALSE) +
            theme_minimal() +
            theme(plot.title = element_blank(),
                  plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                  plot.caption.position = "plot",
                  axis.title = element_text(size = 12),
                  axis.text = element_text(size = 10),
                  panel.grid.minor = element_blank(),
                  panel.grid.major = element_line(color = "gray90", linewidth = 0.3),
                  axis.line = element_line(color = "black", linewidth = 0.5),
                  panel.background = element_rect(color = NA, fill = "white", linewidth = 0),
                  plot.background = element_rect(fill = "white", color = NA, linewidth = 0),
                  legend.position = "bottom",
                  legend.title = element_text(size = 10),
                  legend.text = element_text(size = 10))
        
        if (nrow(plot_data) < 8) {
            p <- p + geom_text(aes(label = 学校_标签), size = 3, vjust = -0.8, show.legend = FALSE)
        }
        
        # 存储高度信息
        attr(p, "plot_height") <- 5
        
        return(list(table = school_cv_table, plot = p))
    }, error = function(e) {
        warning(paste("generate_school_cv_scatter函数执行失败：", e$message))
        return(NULL)
    })
}

# 7.11. generate_radar_chart函数（雷达图）
generate_radar_chart <- function(data, value_col = "知识点得分率", label_col = "核心考点", 
                                 color_palette, title = "雷达图") {
    tryCatch({
        if (is.null(data) || nrow(data) == 0) {
            warning("数据为空")
            return(NULL)
        }
        
        # 提取数值（去掉%符号）
        data$value_numeric <- as.numeric(gsub("%", "", data[[value_col]]))
        
        # 移除缺失值，但保持原始顺序（不排序）
        plot_data <- data[!is.na(data$value_numeric), ]
        
        if (nrow(plot_data) == 0) {
            warning("没有有效数据用于绘图")
            return(NULL)
        }
        
        # 获取维度数量和标签（保持原始顺序）
        n_dims <- nrow(plot_data)
        labels <- plot_data[[label_col]]
        values <- plot_data$value_numeric
        
        # 计算角度（每个维度平均分配360度）
        # 对于n个维度，角度应该是：0, 2π/n, 4π/n, ..., 2π(n-1)/n
        # 使用 seq(0, 2*pi, length.out = n_dims+1) 然后去掉最后一个（等于第一个）
        angles_full <- seq(0, 2 * pi, length.out = n_dims + 1)
        angles <- angles_full[1:n_dims]  # 去掉最后一个（等于第一个，即0）
        # 为了确保闭合，最后一个点的角度应该是2π（而不是0），这样在极坐标中会正确连接
        # 但为了保持数据一致性，我们添加角度为2π的点（等于第一个点）
        angles_closed <- c(angles, 2 * pi)  # 使用2π而不是0，确保在极坐标中正确闭合
        values_closed <- c(values, values[1])
        labels_closed <- c(labels, labels[1])
        
        # 创建数据框用于绘图（确保按角度顺序排列）
        radar_data <- data.frame(
            angle = angles_closed,
            value = values_closed,
            label = labels_closed,
            order = 1:length(angles_closed)  # 添加顺序列
        )
        
        # 确保按角度顺序排列（虽然应该已经是顺序的，但为了保险）
        radar_data <- radar_data[order(radar_data$order), ]
        
        # 计算标签位置（稍微向外一点）
        label_radius <- max(values_closed) * 1.3
        
        # 计算标签的x和y坐标
        radar_data$label_x <- label_radius * cos(radar_data$angle)
        radar_data$label_y <- label_radius * sin(radar_data$angle)
        
        # 计算坐标轴范围
        max_value <- max(values_closed, na.rm = TRUE)
        # 为了美观，将最大值向上取整到最近的10的倍数
        max_value_rounded <- ceiling(max_value / 10) * 10
        
        # 创建背景网格数据
        grid_levels <- c(0.25, 0.5, 0.75, 1.0)
        grid_data <- data.frame()
        for (level in grid_levels) {
            grid_angles <- seq(0, 2*pi, length.out = 100)
            grid_data <- rbind(grid_data, data.frame(
                angle = grid_angles,
                value = max_value_rounded * level,
                level = level
            ))
        }
        
        # 创建轴线数据
        axis_data <- data.frame(
            angle = angles[1:n_dims],
            value_start = 0,
            value_end = max_value_rounded
        )
        
        # 计算标签位置（根据角度动态调整，左右标签需要更远以避免重叠）
        # 对于左右两侧的标签（角度接近0或π），需要更大的半径
        label_radius_base <- max_value_rounded * 1.3
        label_radius <- numeric(n_dims)
        for (i in 1:n_dims) {
            angle_deg <- angles[i] * 180 / pi
            # 计算标签在水平方向上的投影距离
            # 对于左右两侧（角度接近0°或180°），需要更大的半径，往外移动更多
            if (abs(cos(angles[i])) > 0.7) {  # 左右两侧（角度接近0°或180°）
                label_radius[i] <- label_radius_base * 1.6  # 从1.2增加到1.6，使左右标签更远离中心
            } else {  # 上下两侧，保持原位置
                label_radius[i] <- label_radius_base
            }
        }
        
        # 计算标签的x和y坐标（在极坐标中，x是角度，y是半径）
        label_data <- data.frame(
            angle = angles[1:n_dims],
            value = label_radius,
            label = labels[1:n_dims]
        )
        
        # 计算数值标签位置（根据角度动态调整，左右标签需要更远以避免重叠）
        value_label_radius <- numeric(n_dims)
        for (i in 1:n_dims) {
            # 对于左右两侧（角度接近0°或180°），需要更大的半径，往外移动更多
            if (abs(cos(angles[i])) > 0.7) {  # 左右两侧（角度接近0°或180°）
                value_label_radius[i] <- values[i] * 1.3  # 左右两侧往外移动更多
            } else {  # 上下两侧，保持原位置
                value_label_radius[i] <- values[i] * 1.15
            }
        }
        
        # 计算数值标签位置
        value_label_data <- data.frame(
            angle = angles[1:n_dims],
            value = value_label_radius,
            label = paste0(round(values[1:n_dims], 1), "%")
        )
        
        # 计算Y轴上限（根据最大标签半径和最大数值标签半径）
        max_value_label_radius <- max(value_label_radius)
        max_label_radius <- max(max(label_radius), max_value_label_radius)
        
        # 绘制雷达图
        p <- ggplot(radar_data, aes(x = angle, y = value)) +
            # 添加背景网格线（同心圆）
            geom_path(data = grid_data, aes(x = angle, y = value, group = level), 
                     color = "gray80", linewidth = 0.3, inherit.aes = FALSE) +
            # 添加轴线（从中心到每个维度）
            geom_segment(data = axis_data, 
                        aes(x = angle, y = value_start, xend = angle, yend = value_end),
                        color = "gray80", linewidth = 0.3, inherit.aes = FALSE) +
            # # 绘制雷达图多边形（先绘制路径，不包括闭合点） md不要线了
            # geom_path(data = radar_data[1:n_dims, ], 
            #          color = color_palette$color_1[1], linewidth = 1, inherit.aes = TRUE) +
            # 填充多边形（使用geom_polygon，数据包含所有点包括闭合点）
            geom_polygon(fill = color_palette$color_1[1], alpha = 0.3, 
                        color = NA, linewidth = 0) +
            # 添加数据点（只显示原始点，不包括闭合点）
            geom_point(data = radar_data[1:n_dims, ], size = 3.5, color = color_palette$color_1[1], 
                      inherit.aes = TRUE) +
            # 添加维度标签
            geom_text(data = label_data, aes(x = angle, y = value, label = label),
                     hjust = 0.6, vjust = 0.5, size = 4,
                     inherit.aes = FALSE) +
            # 添加数值标签
            geom_text(data = value_label_data, aes(x = angle, y = value, label = label),
                     hjust = 0.5, vjust = 0.5, size = 4,
                     inherit.aes = FALSE) +
            # 使用极坐标（从顶部开始，顺时针）
            # 注意：coord_polar会自动处理闭合，但需要确保数据点按正确顺序
            coord_polar(start = -pi/2, direction = 1, clip = "off") +
            # 设置Y轴范围（减少上限倍数，减少空白）
            scale_y_continuous(limits = c(0, max_label_radius * 1.1), expand = c(0, 0)) +
            labs(caption = title) +
            theme_void() +
            theme(plot.caption = element_text(hjust = 0.5, size = 15, family = "STKaiti"),
                  plot.caption.position = "plot",
                  plot.background = element_rect(fill = "white", color = NA, linewidth = 0))
        
        # 存储高度信息
        attr(p, "plot_height") <- 6
        
        return(list(table = data, plot = p))
    }, error = function(e) {
        warning(paste("generate_radar_chart函数执行失败：", e$message))
        return(NULL)
    })
}

# 8. multichoice_distribution函数
generate_multichoice_distribution <- function(dat, index_report_row, i, color_palette) {
    tryCatch({
        # 获取报告维度（题目文本）
        item <- index_report_row$报告维度
        if (is.na(item) || item == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 获取图表类型，决定是否乘以100和是否显示百分号
        chart_type <- index_report_row$图表类型
        is_percent_type <- !is.na(chart_type) && chart_type == "multichoice_distribution"
        
        # 在dat的列名中找到所有包含item字符的列
        all_cols <- colnames(dat)
        matching_cols <- all_cols[grepl(item, all_cols, fixed = TRUE)]
        
        # 去掉完全匹配的列
        matching_cols <- matching_cols[matching_cols != item]
        
        if (length(matching_cols) == 0) {
            warning(paste("第", i, "行：未找到包含", item, "的列"))
            return(NULL)
        }
        
        # 计算每列的均值
        result_table <- data.frame(
            指标 = character(),
            值 = numeric(),
            stringsAsFactors = FALSE
        )
        
        for (col in matching_cols) {
            mean_val <- mean(dat[[col]], na.rm = TRUE)
            
            # 根据图表类型决定是否乘以100
            if (is_percent_type) {
                mean_val <- mean_val * 100
            }
            
            # 去掉前缀（item文本和"_"）
            # 转义所有正则表达式特殊字符：. \ | ( ) [ { ^ $ * + ?
            escaped_item <- gsub("([][)(}{.*+?^$\\\\|])", "\\\\\\1", item)
            indicator_name <- sub(paste0("^", escaped_item, "_"), "", col)
            # 如果去除前缀后，剩余字符串开头是数字和点号（如"1."），则继续去除
            indicator_name <- sub("^\\d+\\.", "", indicator_name)
            
            result_table <- rbind(result_table, data.frame(
                指标 = indicator_name,
                值 = mean_val
            ))
        }
        
        # 按值从大到小排序
        result_table <- result_table[order(result_table$值, decreasing = TRUE), ]
        
        # 处理Y轴标签：如果字符数超过20，每20个字符插入换行符
        result_table$指标_格式化 <- sapply(result_table$指标, function(label) {
            if (nchar(label) > 21) {
                # 每20个字符插入换行符
                chars <- strsplit(label, "")[[1]]
                n <- length(chars)
                result <- ""
                for (i in seq(1, n, by = 21)) {
                    end_idx <- min(i + 19, n)
                    segment <- paste(chars[i:end_idx], collapse = "")
                    if (i == 1) {
                        result <- segment
                    } else {
                        result <- paste0(result, "\n", segment)
                    }
                }
                return(result)
            } else {
                return(label)
            }
        })
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_7_multichoice_distribution.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 绘制条形图（动态高度）
        n_bars <- nrow(result_table)
        plot_height <- max(2.5, n_bars * 0.3)
        
        # 计算X轴breaks和上限
        max_val <- max(result_table$值, na.rm = TRUE)
        
        if (is_percent_type) {
            # 百分比类型：每10显示
        x_breaks <- seq(0, ceiling(max_val / 10) * 10, by = 10)
        x_max <- max(max_val * 1.15, ceiling(max_val / 10) * 10 + 10)
            # X轴标签格式：添加百分号
            x_label_format <- function(x) paste0(x, "%")
            # 文本标签格式：添加百分号
            label_format <- function(x) paste0(round(x, 1), "%")
        } else {
            # 非百分比类型：根据最大值动态设置breaks
            if (max_val <= 1) {
                x_breaks <- seq(0, 1, by = 0.1)
                x_max <- 1.15
            } else if (max_val <= 10) {
                x_breaks <- seq(0, ceiling(max_val), by = 1)
                x_max <- max(max_val * 1.15, ceiling(max_val) + 1)
            } else {
                x_breaks <- seq(0, ceiling(max_val / 10) * 10, by = 10)
                x_max <- max(max_val * 1.15, ceiling(max_val / 10) * 10 + 10)
            }
            # X轴标签格式：不添加百分号
            x_label_format <- function(x) as.character(round(x, 1))
            # 文本标签格式：不添加百分号
            label_format <- function(x) as.character(round(x, 1))
        }
        
        # 创建指标名称到格式化标签的映射（用于Y轴标签）
        y_label_mapping <- setNames(result_table$指标_格式化, result_table$指标)
        
        p <- ggplot(result_table, aes(x = 值, y = reorder(指标, 值))) +
            geom_bar(stat = "identity", fill = color_palette$color_1[1], width = 0.4) +
            geom_text(aes(label = label_format(值)), hjust = -0.1, size = 3) +
            labs(caption = ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题),
                 x = "", y = "") +
            scale_x_continuous(labels = x_label_format, breaks = x_breaks, limits = c(0, x_max), expand = c(0, 0)) +
            scale_y_discrete(labels = function(x) y_label_mapping[x]) +
            theme_minimal() +
            theme(legend.position = "none",
                  plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                  plot.caption.position = "plot",  # 相对于整个绘图区域居中（包括图例）
                  axis.text.y = element_text(angle = 0),
                  panel.grid = element_blank(),  # 去掉所有背景网格线
                  axis.line = element_line(color = "black"))  # 添加X轴和Y轴线
        
        # 存储高度信息
        attr(p, "plot_height") <- plot_height
        
        return(list(table = result_table, plot = p))
    }, error = function(e) {
        warning(paste("第", i, "行：multichoice_distribution函数执行失败：", e$message))
        return(NULL)
    })
}

# 8. bar_chart_years函数
# 注意，这个是读取线下表格来画图，函数里中职/高中的file path不一样，需要根据报告学段来确定file path
generate_bar_chart_years <- function(dat, index_report_row, i, color_palette) {
    tryCatch({
        # 获取图题表题作为文件名
        title <- index_report_row$图题表题
        if (is.na(title) || title == "") {
            warning(paste("第", i, "行：图题表题为空"))
            return(NULL)
        }
        
        # 读取Excel文件
        if (index_report_row$报告学段 == "高中") {
            file_path <- paste0("9 pics and tables/1 h/table_", title, ".xlsx")
        }else if (index_report_row$报告学段 == "中职") {
            file_path <- paste0("9 pics and tables/2 c/table_", title, ".xlsx")
        }else {
            warning(paste("第", i, "行：报告学段为空"))
            return(NULL)
        }
        
        if (!file.exists(file_path)) {
            warning(paste("第", i, "行：文件不存在：", file_path))
            return(NULL)
        }
        
        # 读取表格数据
        table_data <- openxlsx::read.xlsx(file_path)
        
        if (nrow(table_data) == 0 || ncol(table_data) < 2) {
            warning(paste("第", i, "行：表格数据为空或列数不足"))
            return(NULL)
        }
        
        # 获取第一列作为年份列
        year_col <- colnames(table_data)[1]
        if (!year_col %in% colnames(table_data)) {
            warning(paste("第", i, "行：未找到年份列"))
            return(NULL)
        }
        
        # 去掉列名为"其他"的列
        if ("其他" %in% colnames(table_data)) {
            table_data <- table_data %>% select(-"其他")
        }
        
        # 获取分类列（除了第一列年份列）
        category_cols <- colnames(table_data)[-1]
        if (length(category_cols) == 0) {
            warning(paste("第", i, "行：没有分类列"))
            return(NULL)
        }
        
        # 将数字列转为数值格式（处理"-"等非数值字符）
        for (col in category_cols) {
            # 先将"-"转换为NA
            table_data[[col]] <- ifelse(table_data[[col]] == "-" | table_data[[col]] == "", NA, table_data[[col]])
            table_data[[col]] <- as.numeric(as.character(table_data[[col]]))
        }
        
        # 将数据从宽格式转换为长格式
        # 使用tidyr::pivot_longer
        result_table <- table_data %>%
            tidyr::pivot_longer(cols = all_of(category_cols), 
                        names_to = "分类", 
                        values_to = "占比")
        
        # 重命名年份列
        colnames(result_table)[colnames(result_table) == year_col] <- "年份"
        
        # 处理NA值
        result_table <- result_table %>%
            filter(!is.na(占比))
        
        if (nrow(result_table) == 0) {
            warning(paste("第", i, "行：处理后数据为空"))
            return(NULL)
        }
        
        # 获取年份数量和颜色
        years <- unique(result_table$年份)
        n_years <- length(years)
        
        # 根据年份数量选择颜色
        color_key <- paste0("color_", n_years)
        if (color_key %in% names(color_palette)) {
            colors <- color_palette[[color_key]]
        } else if (n_years <= length(color_palette$color_6)) {
            colors <- color_palette$color_6[1:n_years]
        } else {
            # 如果年份数量超过6，使用默认颜色
            colors <- rainbow(n_years)
        }
        
        # 创建年份到颜色的映射
        year_color_mapping <- setNames(colors, years)
        
        # 保持分类的原始顺序（按照在表格中出现的顺序）
        # 反转顺序，使得第一个列名在图的顶部（从上到下）
        category_order <- category_cols
        result_table$分类 <- factor(result_table$分类, levels = rev(category_order))
        
        # 处理Y轴标签：如果字符数超过20，每20个字符插入换行符
        result_table$分类_格式化 <- sapply(result_table$分类, function(label) {
            label_str <- as.character(label)
            if (nchar(label_str) > 20) {
                chars <- strsplit(label_str, "")[[1]]
                n <- length(chars)
                result <- ""
                for (j in seq(1, n, by = 20)) {
                    end_idx <- min(j + 19, n)
                    segment <- paste(chars[j:end_idx], collapse = "")
                    if (j == 1) {
                        result <- segment
                    } else {
                        result <- paste0(result, "\n", segment)
                    }
                }
                return(result)
            } else {
                return(label_str)
            }
        })
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_bar_chart_years.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 绘制分组条形图（动态高度）
        # 每个类别有3-5个分组的柱子，需要更多高度
        n_categories <- length(unique(result_table$分类))
        plot_height <- max(2.5, n_categories * 0.6)
        
        # X轴设置：0-100
        x_breaks <- seq(0, 100, by = 10)
        x_max <- 109
        
        # 创建分类名称到格式化标签的映射（用于Y轴标签）
        y_label_mapping <- result_table %>%
            select(分类, 分类_格式化) %>%
            distinct() %>%
            {setNames(.$分类_格式化, as.character(.$分类))}
        
        # 计算图例需要的行数（参考stack_bar_var_distribution）
        n_legend_items <- n_years
        n_string_length <- sum(nchar(as.character(unique(result_table$年份))))
        
        legend_nrow <- if (n_legend_items <= 3) {
            1
        } else if (n_legend_items <= 6 & n_string_length <= 50) {
            2
        } else {
            3
        }
        
        # 创建分组条形图
        p <- ggplot(result_table, aes(x = 占比, y = 分类, fill = 年份)) +
            geom_bar(stat = "identity", position = "dodge", width = 0.6) +
            geom_text(aes(label = paste0(round(占比, 1), "%")), 
                     position = position_dodge(width = 0.6), 
                     hjust = -0.1, size = 3) +
            labs(caption = ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题),
                 x = "选择人数占比（%）", y = "") +
            scale_x_continuous(breaks = x_breaks, limits = c(0, x_max), expand = c(0, 0)) +
            scale_y_discrete(labels = function(x) y_label_mapping[x]) +
            scale_fill_manual(values = year_color_mapping, name = "") +
            guides(fill = guide_legend(nrow = legend_nrow, byrow = TRUE)) +  # 控制图例行数，按行填充
            theme_minimal() +
            theme(legend.position = "bottom",
                  plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                  plot.caption.position = "plot",
                  axis.text.y = element_text(angle = 0),
                  panel.grid = element_blank(),
                  axis.line = element_line(color = "black"),
                  legend.key.height = unit(0.5, "lines"),  # 图例方块高度为原来的1/2
                  legend.key.width = unit(1, "lines"),  # 图例方块宽度保持不变
                  legend.text = element_text(size = 9, family = "PingFang SC"),
                  text = element_text(family = "PingFang SC"))
        
        # 存储高度信息
        attr(p, "plot_height") <- plot_height
        
        return(list(table = result_table, plot = p))
    }, error = function(e) {
        warning(paste("第", i, "行：bar_chart_years函数执行失败：", e$message))
        return(NULL)
    })
}

# 9. pie_distribution函数
generate_pie_distribution <- function(dat, index_report_row, index_item, i, color_palette) {
    tryCatch({
        dim_or_item <- index_report_row$dim_or_item
        if (is.na(dim_or_item) || dim_or_item == "") {
            warning(paste("第", i, "行：dim_or_item为空"))
            return(NULL)
        }
        
        # 获取报告维度
        dim_or_item_value <- index_report_row$报告维度
        if (is.na(dim_or_item_value) || dim_or_item_value == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 确定要分析的列
        if (dim_or_item == "dim") {
            analysis_col <- paste0(dim_or_item_value, "_Class")
        } else {
            analysis_col <- dim_or_item_value
        }
        
        if (!analysis_col %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到变量", analysis_col))
            return(NULL)
        }
        
        # 根据数据表对应过滤index_item
        index_item_filtered <- filter_index_item_by_data_table(index_item, index_report_row)
        
        # 获取类别
        if (dim_or_item == "dim") {
            # 从index_item中获取报告维度分类名
            # 首先在"报告维度"列中查找
            item_row <- index_item_filtered %>% filter(报告维度 == dim_or_item_value) %>% slice(1)
            # 如果找不到，则在"子维度"列中查找
            if (nrow(item_row) == 0 && "子维度" %in% colnames(index_item_filtered)) {
                item_row <- index_item_filtered %>% filter(子维度 == dim_or_item_value) %>% slice(1)
            }
            # 如果都找不到，报warning
            if (nrow(item_row) == 0) {
                warning(paste("第", i, "行：未找到维度", dim_or_item_value, "的信息（在报告维度和子维度中都未找到）"))
                return(NULL)
            }
            
            # 获取分类名（假设有报告维度分类名1、2、3等列）
            categories <- c()
            for (j in 1:10) {
                col_name <- paste0("报告维度分类名", j)
                if (col_name %in% colnames(index_item_filtered)) {
                    cat_val <- item_row[[col_name]]
                    if (!is.na(cat_val) && cat_val != "") {
                        categories <- c(categories, as.character(cat_val))
                    }
                }
            }
        } else if (dim_or_item == "item") {
            # 从index_item中获取选项
            item_row <- index_item_filtered %>% filter(题目列名 == dim_or_item_value) %>% slice(1)
            if (nrow(item_row) == 0) {
                warning(paste("第", i, "行：未找到题目", dim_or_item_value, "的信息"))
                return(NULL)
            }
            
            options_str <- item_row$选项
            if (is.na(options_str) || options_str == "") {
                warning(paste("第", i, "行：题目", dim_or_item_value, "的选项为空"))
                return(NULL)
            }
            
            categories <- strsplit(options_str, "//C//", fixed = TRUE)[[1]]
            categories <- trimws(categories)
        } else if (dim_or_item == "basic") {
            # 从数据中直接获取类别
            # 判断当前变量是否为factor
            if (is.factor(dat[[analysis_col]])) {
                categories <- levels(dat[[analysis_col]])
            } else {
                categories <- unique(dat[[analysis_col]])
                categories <- categories[!is.na(categories)]
                categories <- as.character(categories)
            }
        }
        
        if (length(categories) == 0) {
            warning(paste("第", i, "行：未找到类别"))
            return(NULL)
        }
        
        # 处理分类名：去掉2个或以上的下划线，以及零宽度字符
        categories <- gsub("_{2,}", "", categories)
        # 清理零宽度字符（如零宽度空格、零宽度断字符等）
        categories <- gsub("[\u200b\u200c\u200d\ufeff]", "", categories, perl = TRUE)
        
        # 计算每个类别的占比
        result_table <- data.frame(
            类别 = categories,
            占比 = numeric(length(categories)),
            stringsAsFactors = FALSE
        )
        
        # 获取数据中实际存在的所有类别
        actual_categories <- unique(dat[[analysis_col]])
        actual_categories <- actual_categories[!is.na(actual_categories)] %>%
            sapply(., function(x) {
            if (is.na(x)) return(NA_character_)
            # 检查是否以"其他"开头
            if (grepl("^其他", x)) {
                return("其他")
            } else {
                return(x)
            }
        }, USE.NAMES = FALSE) %>%
        unique()
        
        
        
        # 处理数据中的值：如果以"其他"开头（后面可能是空、特殊字符、"（"），统一转换为"其他"
        dat_processed <- as.character(dat[[analysis_col]])
        dat_processed <- sapply(dat_processed, function(x) {
            if (is.na(x)) return(NA_character_)
            # 检查是否以"其他"开头
            if (grepl("^其他", x)) {
                return("其他")
            } else {
                return(x)
            }
        }, USE.NAMES = FALSE)
        
        # 只计算在categories中定义的类别
        for (j in seq_along(categories)) {
            n_count <- sum(dat_processed == categories[j], na.rm = TRUE)
            n_total <- sum(!is.na(dat[[analysis_col]]))
            if (n_total > 0) {
                result_table$占比[j] <- (n_count / n_total) * 100
            }
        }
        
        # 检查占比总和
        total_pct <- sum(result_table$占比, na.rm = TRUE)
        if (total_pct > 100.01) {
            # 如果总和>100%，记录错误
            warning(paste("第", i, "行：pie_distribution占比总和超过100%：", round(total_pct, 2), "%"))
        }
        # 不进行归一化，保持原始占比值
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_8_pie_distribution.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 检查图表类型，判断是否需要转换为条形图
        chart_type <- index_report_row$图表类型
        is_trans_bar <- !is.na(chart_type) && chart_type == "pie_distribution_trans_bar"
        
        if (is_trans_bar) {
            # 转换为条形图：样式与simple_bar_dis_figures相似
            # 确保类别顺序（从大到小排序，用于条形图）
            result_table <- result_table[order(result_table$占比, decreasing = TRUE), ]
            
            # 对类别文本进行换行处理
            result_table$类别 <- sapply(result_table$类别, function(x) {
                x_str <- as.character(x)
                char_count <- nchar(x_str)
                
                if (char_count > 8 && char_count <= 16) {
                    # 字数 > 8 且 <= 16：平均分为两段（中间插入一个 \n）
                    mid_point <- ceiling(char_count / 2)
                    return(paste0(substr(x_str, 1, mid_point), "\n", substr(x_str, mid_point + 1, char_count)))
                } else if (char_count > 16) {
                    # 字数 > 16：分为三段
                    segment_length <- ceiling(char_count / 3)
                    seg1_end <- segment_length
                    seg2_end <- segment_length * 2
                    return(paste0(
                        substr(x_str, 1, seg1_end), "\n",
                        substr(x_str, seg1_end + 1, seg2_end), "\n",
                        substr(x_str, seg2_end + 1, char_count)
                    ))
                } else {
                    # 字数 <= 8：不换行
                    return(x_str)
                }
            })
            
            result_table$类别 <- factor(result_table$类别, levels = result_table$类别)
            
            # 准备标签文本
            result_table$label_text <- paste0(round(result_table$占比, 1), "%")
            
            # 计算Y轴上限（类似simple_bar_dis_figures的逻辑）
            y_max_pct <- max(result_table$占比, na.rm = TRUE)
            if (y_max_pct <= 0) {
                y_upper_limit <- 10
            } else if (y_max_pct < 20) {
                y_upper_limit <- ceiling(max(y_max_pct * 1.15, y_max_pct + 5) / 5) * 5
            } else if (y_max_pct < 50) {
                y_upper_limit <- ceiling(max(y_max_pct * 1.12, y_max_pct + 10) / 10) * 10
            } else if (y_max_pct < 80) {
                y_upper_limit <- ceiling(max(y_max_pct * 1.1, y_max_pct + 10) / 10) * 10
            } else {
                y_upper_limit <- min(105, ceiling(max(y_max_pct * 1.05, y_max_pct + 5) / 5) * 5)
            }
            
            # 设置breaks间隔
            if (y_max_pct <= 20) {
                breaks_interval <- 5
            } else {
                breaks_interval <- 10
            }
            y_breaks <- seq(0, y_upper_limit, by = breaks_interval)
            
            # 所有bar使用color_1_highlight颜色
            color_values <- rep(color_palette$color_1_highlight[1], nrow(result_table))
            names(color_values) <- result_table$类别
            
            # 创建条形图
            p <- ggplot(result_table, aes(x = 类别, y = 占比, fill = 类别)) +
                geom_bar(stat = "identity", width = 0.4) +
                geom_text(aes(label = label_text), vjust = -0.5, size = 3) +
                scale_fill_manual(values = color_values) +
                labs(caption = ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题),
                     x = "", y = "") +
                scale_y_continuous(labels = function(x) paste0(x, "%"),
                                 breaks = y_breaks,
                                 limits = c(0, y_upper_limit),
                                 expand = c(0, 0)) +
                theme_minimal() +
                theme(legend.position = "none",
                      plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                      plot.caption.position = "plot",
                      axis.text.x = element_text(angle = 0),
                      panel.grid = element_blank(),
                      axis.line = element_line(color = "black"))
            
            # 设置高度属性
            attr(p, "plot_height") <- 3
            
            return(list(table = result_table, plot = p))
        }
        
        # 以下是原有的饼图逻辑
        result_table$类别 <- factor(result_table$类别, levels = rev(result_table$类别))
        cumsum_pct <- c(0, cumsum(result_table$占比)[-nrow(result_table)]) # 前一个扇形的结束位置
        label_pos <-  cumsum_pct + result_table$占比 / 2 # 当前扇形的中心位置

        # 使用颜色映射函数（特殊处理"达标"和"不达标"）
        # pie_distribution 使用反向颜色顺序
        color_mapping <- get_color_mapping(result_table$类别, color_palette, reverse = TRUE)

        # 创建饼图
        # 设置中文字体（macOS常用字体：PingFang SC, STHeiti, STSong, Hiragino Sans GB）
        chinese_font <- "PingFang SC"  # macOS系统默认中文字体
        
        # 计算饼图的y轴范围（0到占比总和），用于固定坐标轴，防止拉线影响扇形
        total_pct_sum <- sum(result_table$占比, na.rm = TRUE)
        # 使用占比总和作为上限，但如果总和小于100，使用100（避免占比总和不足100时出现空白）
        y_axis_limit <- ifelse(total_pct_sum < 100, 100, total_pct_sum)
        
        # 处理图例标签：如果字符数超过20，每20个字符插入换行符
        legend_labels <- levels(result_table$类别)
        legend_labels_formatted <- sapply(legend_labels, function(label) {
            if (nchar(label) > 20) {
                # 每20个字符插入换行符
                chars <- strsplit(label, "")[[1]]
                n <- length(chars)
                result <- ""
                for (i in seq(1, n, by = 20)) {
                    end_idx <- min(i + 19, n)
                    segment <- paste(chars[i:end_idx], collapse = "")
                    if (i == 1) {
                        result <- segment
                    } else {
                        result <- paste0(result, "\n", segment)
                    }
                }
                return(result)
            } else {
                return(label)
            }
        })
        names(legend_labels_formatted) <- legend_labels
        
        p <- ggplot(result_table, aes(x = "", y = 占比, fill = 类别)) +
            geom_bar(stat = "identity", width = 1, color = "white", linewidth = 0.5) +
            coord_polar("y", start = 0) +
            scale_y_continuous(limits = c(0, y_axis_limit), expand = c(0, 0)) +
            scale_fill_manual(values = color_mapping, 
                            breaks = levels(result_table$类别),
                            labels = legend_labels_formatted) +
            labs(caption = ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题),
                fill = "") +
            theme_void() +
            theme(legend.position = "right",
                plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                plot.caption.position = "plot",  # 相对于整个绘图区域居中（包括图例）
                legend.title = element_text(size = 10, family = chinese_font),
                legend.text = element_text(size = 9, family = chinese_font),
                text = element_text(family = chinese_font))

        # 添加标签，放在每个扇形的正中心
        # 饼图按 factor levels 逆时针绘制（从12点位置开始）
        # 如果标签顺序和饼图顺序相反，需要反转 label_pos 和 label 的顺序
        # 尝试反转顺序，使标签与饼图的逆时针顺序一致
        
        # 反转后的数据（与饼图绘制顺序一致）
        rev_label_pos <- rev(label_pos)
        rev_pct <- rev(result_table$占比)
        rev_labels <- rev(paste0(round(result_table$占比, 1), "%"))
        
        # 判断哪些标签需要拉线（占比 < 2.5%）
        need_line <- rev_pct < 2.5
        
        # 设置标签位置：需要拉线的放在外面（x=1.5），不需要的放在里面（x=1.2）
        label_x <- ifelse(need_line, 1.6, 1.2)
        
        # 调整y位置：对于连续的拉线标签，错开y位置
        adjusted_y <- rev_label_pos
        
        if (any(need_line)) {
            # 找到所有需要拉线的标签索引
            line_indices <- which(need_line)
            
            # 检测连续的拉线标签组
            if (length(line_indices) > 1) {
                # 计算连续组
                consecutive_groups <- list()
                current_group <- c(line_indices[1])
                
                for (i in 2:length(line_indices)) {
                    if (line_indices[i] == line_indices[i-1] + 1) {
                        # 连续的
                        current_group <- c(current_group, line_indices[i])
                    } else {
                        # 不连续，保存当前组，开始新组
                        if (length(current_group) > 1) {
                            consecutive_groups[[length(consecutive_groups) + 1]] <- current_group
                        }
                        current_group <- c(line_indices[i])
                    }
                }
                # 保存最后一组
                if (length(current_group) > 1) {
                    consecutive_groups[[length(consecutive_groups) + 1]] <- current_group
                }
                
                # 对于每个连续组，错开y位置
                for (group in consecutive_groups) {
                    if (length(group) > 1) {
                        # 计算错开量：向上和向下交替
                        # 使用固定的错开量，让连续标签之间的差异更明显
                        base_offset <- 4  # 固定错开量，每个标签错开4个单位
                        
                        for (idx in seq_along(group)) {
                            pos_idx <- group[idx]
                            
                            # 错开量：奇数向上，偶数向下
                            # 第1个：+0，第2个：-base_offset，第3个：+base_offset，第4个：-base_offset*2，第5个：+base_offset*2...
                            if (idx == 1) {
                                # 第一个标签保持原位置
                                offset <- 0
                            } else if (idx %% 2 == 0) {
                                # 偶数：向下错开（第2个-base_offset，第4个-base_offset*2...）
                                offset <- -(idx / 2) * base_offset
                            } else {
                                # 奇数（除了第1个）：向上错开（第3个+base_offset，第5个+base_offset*2...）
                                offset <- ((idx - 1) / 2) * base_offset
                            }
                            
                            adjusted_y[pos_idx] <- adjusted_y[pos_idx] + offset
                            # 确保调整后的y位置在有效范围内（0到y_axis_limit）
                            adjusted_y[pos_idx] <- pmax(0, pmin(y_axis_limit, adjusted_y[pos_idx]))
                        }
                    }
                }
            }
        }
        
        # 创建标签数据框
        label_data <- data.frame(
            x = label_x,
            y = adjusted_y,
            y_original = rev_label_pos,  # 原始位置，用于拉线起点
            label = rev_labels,
            need_line = need_line,
            stringsAsFactors = FALSE
        )
        
        # 添加拉线（仅对占比 < 2.5% 的标签）
        # 使用geom_segment，但确保不影响饼图的坐标轴设置
        if (any(need_line)) {
            line_data <- label_data[need_line, ]
            # 过滤掉超出y轴范围的数据（y_original和y都必须在[0, y_axis_limit]范围内）
            line_data <- line_data[line_data$y_original >= 0 & line_data$y_original <= y_axis_limit & 
                                  line_data$y >= 0 & line_data$y <= y_axis_limit & 
                                  !is.na(line_data$y_original) & !is.na(line_data$y), ]
            if (nrow(line_data) > 0) {
                p <- p + geom_segment(data = line_data,
                                    aes(x = 1, xend = x, y = y_original, yend = y),
                                    inherit.aes = FALSE,
                                    color = "black",
                                    linewidth = 0.3,
                                    show.legend = FALSE)
            }
        }
        
        # 添加标签文本
        p <- p + geom_text(data = label_data, 
                        aes(x = x, y = y, label = label),
                        inherit.aes = FALSE,
                        size = 3.5,
                        fontface = "bold",
                        family = chinese_font)
        
        # 设置饼图高度（降低高度）
        attr(p, "plot_height") <- 2.5
        
        return(list(table = result_table, plot = p))
    }, error = function(e) {
        warning(paste("第", i, "行：pie_distribution函数执行失败：", e$message))
        return(NULL)
    })
}

# 9. stack_bar_var_distribution函数
generate_stack_bar_var_distribution <- function(dat, index_report_row, index_item, i, color_palette, hide_other_labels = FALSE, target_district = NULL,
                                                is_three_level_compare = FALSE, dat_qd = NULL, dat_dist = NULL, school_name = NULL) {
    # index 中 stack 文案与数据列（数值/因子/字符）对齐；交叉变量取值与 y_cat 对齐
    filter_stack_categories_in_data <- function(sc, colv) {
        sc <- sc[!is.na(sc) & nzchar(trimws(as.character(sc)))]
        if (length(sc) == 0) return(sc)
        u <- colv[!is.na(colv)]
        if (length(u) == 0) return(sc[FALSE])
        uu <- unique(u)
        if (any(sc %in% uu)) return(sc[sc %in% uu])
        u_chr <- unique(trimws(as.character(uu)))
        sc_chr <- trimws(as.character(sc))
        if (any(sc_chr %in% u_chr)) return(sc[sc_chr %in% u_chr])
        if (is.numeric(uu) || is.integer(uu)) {
            scn <- suppressWarnings(as.numeric(sc_chr))
            ok <- !is.na(scn) & scn %in% uu
            if (any(ok)) return(sc[ok])
        }
        sc[FALSE]
    }
    count_eq_stack <- function(vec, stack_cat) {
        if (length(vec) == 0) return(logical(0))
        if (is.numeric(vec) || is.integer(vec)) {
            sn <- suppressWarnings(as.numeric(stack_cat))
            if (!is.na(sn)) return(vec == sn)
        }
        as.character(vec) == as.character(stack_cat)
    }
    eq_cross_y <- function(colv, y_cat) {
        if (length(colv) == 0) return(logical(0))
        if (is.numeric(colv) || is.integer(colv)) {
            yn <- suppressWarnings(as.numeric(y_cat))
            if (!is.na(yn)) return(colv == yn)
        }
        as.character(colv) == as.character(y_cat)
    }
    tryCatch({
        dim_or_item <- index_report_row$dim_or_item
        if (is.na(dim_or_item) || dim_or_item == "") {
            warning(paste("第", i, "行：dim_or_item为空"))
            return(NULL)
        }
        
        # 获取报告维度
        dim_or_item_value <- index_report_row$报告维度
        if (is.na(dim_or_item_value) || dim_or_item_value == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 确定用于stack的分类变量（由报告维度判断，例如"劳动习惯_Class"）
        if (dim_or_item == "dim") {
            stack_col <- paste0(dim_or_item_value, "_Class")
        } else {
            stack_col <- dim_or_item_value
        }
        
        if (!stack_col %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到stack变量", stack_col))
            return(NULL)
        }
        
        # 根据数据表对应过滤index_item
        index_item_filtered <- filter_index_item_by_data_table(index_item, index_report_row)
        
        # 获取stack变量的类别（用于fill）
        if (dim_or_item == "dim") {
            item_row <- index_item_filtered %>% filter(报告维度 == dim_or_item_value) %>% slice(1)
            if (nrow(item_row) == 0) {
                warning(paste("第", i, "行：未找到维度", dim_or_item_value, "的信息"))
                return(NULL)
            }
            stack_categories <- c()
            for (j in 1:10) {
                col_name <- paste0("报告维度分类名", j)
                if (col_name %in% colnames(index_item_filtered)) {
                    cat_val <- item_row[[col_name]]
                    if (!is.na(cat_val) && cat_val != "") {
                        stack_categories <- c(stack_categories, as.character(cat_val))
                    }
                }
            }
            # 如果是三级对比模式，需要从所有数据源中获取类别；否则只从dat中获取
            if (is_three_level_compare && !is.null(dat_qd) && !is.null(dat_dist)) {
                # 合并所有数据源中的类别
                all_categories <- unique(c(
                    unique(dat[[stack_col]]),
                    unique(dat_qd[[stack_col]]),
                    unique(dat_dist[[stack_col]])
                ))
                all_categories <- all_categories[!is.na(all_categories)]
                stack_categories <- stack_categories[stack_categories %in% all_categories]
            } else {
                # 只保留dat中实际存在的类别
                stack_categories <- stack_categories[stack_categories %in% unique(dat[[stack_col]])]
            }
        } else if (dim_or_item == "item") {
            item_row <- index_item_filtered %>% filter(题目列名 == dim_or_item_value) %>% slice(1)
            if (nrow(item_row) == 0) {
                warning(paste("第", i, "行：未找到题目", dim_or_item_value, "的信息"))
                return(NULL)
            }
            options_str <- item_row$选项
            if (is.na(options_str) || options_str == "") {
                warning(paste("第", i, "行：题目", dim_or_item_value, "的选项为空"))
                return(NULL)
            }
            stack_categories <- strsplit(options_str, "//C//", fixed = TRUE)[[1]]
            stack_categories <- trimws(stack_categories)
            # 如果是三级对比模式，需要从所有数据源中获取类别；否则只从dat中获取
            if (is_three_level_compare && !is.null(dat_qd) && !is.null(dat_dist)) {
                # 合并所有数据源中的类别
                all_categories <- unique(c(
                    unique(dat[[stack_col]]),
                    unique(dat_qd[[stack_col]]),
                    unique(dat_dist[[stack_col]])
                ))
                all_categories <- all_categories[!is.na(all_categories)]
                stack_categories <- stack_categories[stack_categories %in% all_categories]
            } else {
                # 只保留dat中实际存在的类别
                stack_categories <- stack_categories[stack_categories %in% unique(dat[[stack_col]])]
            }
        } else if (dim_or_item == "basic") {
            # 从数据中直接获取类别
            # 如果是三级对比模式，需要从所有数据源中获取类别
            if (is_three_level_compare && !is.null(dat_qd) && !is.null(dat_dist)) {
                # 合并所有数据源中的类别
                all_categories <- unique(c(
                    unique(dat[[stack_col]]),
                    unique(dat_qd[[stack_col]]),
                    unique(dat_dist[[stack_col]])
                ))
                all_categories <- all_categories[!is.na(all_categories)]
                # 判断当前变量是否为factor（优先使用dat中的factor信息）
                if (is.factor(dat[[stack_col]])) {
                    # 使用factor的levels，但只保留在所有数据源中实际存在的类别
                    factor_levels <- levels(dat[[stack_col]])
                    stack_categories <- factor_levels[factor_levels %in% all_categories]
                } else {
                    stack_categories <- as.character(all_categories)
                }
            } else {
                # 判断当前变量是否为factor
                if (is.factor(dat[[stack_col]])) {
                    stack_categories <- levels(dat[[stack_col]])
                } else {
                    stack_categories <- unique(dat[[stack_col]])
                    stack_categories <- stack_categories[!is.na(stack_categories)]
                    stack_categories <- as.character(stack_categories)
                }
            }
        }
        
        ustack_for_filter <- if (is_three_level_compare && !is.null(dat_qd) && !is.null(dat_dist)) {
            unique(c(
                dat[[stack_col]][!is.na(dat[[stack_col]])],
                dat_qd[[stack_col]][!is.na(dat_qd[[stack_col]])],
                dat_dist[[stack_col]][!is.na(dat_dist[[stack_col]])]
            ))
        } else {
            dat[[stack_col]][!is.na(dat[[stack_col]])]
        }
        stack_categories <- filter_stack_categories_in_data(stack_categories, ustack_for_filter)
        if (length(stack_categories) == 0) {
            warning(paste("第", i, "行：stack类别与数据列", stack_col, "无交集（常见于数值编码与 index 选项文案不一致）"))
            return(NULL)
        }
        
        # 三级对比逻辑
        if (is_three_level_compare) {
            # 检查必要的数据是否提供
            if (is.null(dat_qd) || is.null(dat_dist) || is.null(school_name)) {
                warning(paste("第", i, "行：三级对比模式需要提供dat_qd、dat_dist和school_name参数"))
                return(NULL)
            }
            
            # 检查stack_col是否在所有数据中存在
            if (!stack_col %in% colnames(dat_qd) || !stack_col %in% colnames(dat_dist) || !stack_col %in% colnames(dat)) {
                warning(paste("第", i, "行：三级对比模式中，stack_col", stack_col, "不在所有数据中存在"))
                return(NULL)
            }
            
            # 获取学校所在区市（从dat_dist中获取，因为dat_dist已经过滤了该区市的数据）
            if ("区市" %in% colnames(dat_dist) && nrow(dat_dist) > 0) {
                school_district <- as.character(unique(dat_dist$区市)[1])
            } else {
                warning(paste("第", i, "行：无法从dat_dist中确定学校所在的区市"))
                return(NULL)
            }
            
            # 三级对比：Y类别固定为"青岛市"、"区市"、"本校"
            Y_categories <- c("青岛市", school_district, "本校")
            
            # 计算交叉表
            result_table <- data.frame(
                Y类别 = character(),
                stack类别 = character(),
                占比 = numeric(),
                stringsAsFactors = FALSE
            )
            
            # 对于每个Y类别，计算stack类别的占比
            for (y_cat in Y_categories) {
                if (y_cat == "青岛市") {
                    dat_subset <- dat_qd
                } else if (y_cat == school_district) {
                    dat_subset <- dat_dist
                } else if (y_cat == "本校") {
                    dat_subset <- dat
                } else {
                    next
                }
                
                n_total <- sum(!is.na(dat_subset[[stack_col]]))
                
                if (n_total == 0) {
                    next
                }
                
                # 先计算所有类别的原始占比
                pct_values <- c()
                for (stack_cat in stack_categories) {
                    n_count <- sum(count_eq_stack(dat_subset[[stack_col]], stack_cat), na.rm = TRUE)
                    pct <- (n_count / n_total) * 100
                    pct_values <- c(pct_values, pct)
                }
                
                # 归一化确保总和为100%（避免浮点数精度问题）
                if (sum(pct_values) > 0) {
                    pct_values <- pct_values / sum(pct_values) * 100
                }
                
                # 添加到结果表（保持原始精度）
                for (j in seq_along(stack_categories)) {
                    result_table <- rbind(result_table, data.frame(
                        Y类别 = y_cat,
                        stack类别 = stack_categories[j],
                        占比 = pct_values[j]  # 使用原始值，不round
                    ))
                }
            }
        } else {
            # 原有逻辑
            # 确定Y轴变量（交叉或分类变量，例如"区市"）
            Y_var <- index_report_row$交叉或分类变量
            if (is.na(Y_var) || Y_var == "") {
                warning(paste("第", i, "行：交叉或分类变量为空"))
                return(NULL)
            }
            
            if (Y_var %in% basic_vars) {
                Y_col <- Y_var
            } else {
                Y_col <- paste0(Y_var, "_Class")
            }
            
            if (!Y_col %in% colnames(dat)) {
                warning(paste("第", i, "行：未找到Y轴变量", Y_col))
                return(NULL)
            }
            
            # 计算交叉表
            # Y轴显示Y类别（柱子），stack显示stack类别（fill）
            # 需要计算"在每个Y类别中，stack类别的占比"
            result_table <- data.frame(
                Y类别 = character(),
                stack类别 = character(),
                占比 = numeric(),
                stringsAsFactors = FALSE
            )
            
            # 获取Y变量的所有类别（保持factor的levels顺序，用于Y轴）
            if (is.factor(dat[[Y_col]])) {
                Y_categories <- levels(dat[[Y_col]])
                Y_categories <- Y_categories[Y_categories %in% unique(dat[[Y_col]])]
            } else {
                Y_categories <- unique(dat[[Y_col]])
                Y_categories <- Y_categories[!is.na(Y_categories)]
                # 如果不是factor，按字母顺序排序以确保一致性
                Y_categories <- sort(Y_categories)
            }
            
            # 对于每个Y类别，计算stack类别的占比
            for (y_cat in Y_categories) {
                dat_subset <- dat[eq_cross_y(dat[[Y_col]], y_cat) & !is.na(dat[[Y_col]]), ]
                n_total <- sum(!is.na(dat_subset[[stack_col]]))
                
                if (n_total == 0) {
                    next
                }
                
                # 先计算所有类别的原始占比
                pct_values <- c()
                for (stack_cat in stack_categories) {
                    n_count <- sum(count_eq_stack(dat_subset[[stack_col]], stack_cat), na.rm = TRUE)
                    pct <- (n_count / n_total) * 100
                    pct_values <- c(pct_values, pct)
                }
                
                # 归一化确保总和为100%（避免浮点数精度问题）
                if (sum(pct_values) > 0) {
                    pct_values <- pct_values / sum(pct_values) * 100
                }
                
                # 添加到结果表（保持原始精度）
                for (j in seq_along(stack_categories)) {
                    result_table <- rbind(result_table, data.frame(
                        Y类别 = y_cat,
                        stack类别 = stack_categories[j],
                        占比 = pct_values[j]  # 使用原始值，不round
                    ))
                }
            }
            
                # 如果Y变量是"区市"，需要添加总体（青岛市）的计算
                # （2）心理健康教育教师教学 这分专兼职，也需要一个总体
                if (Y_var %in% c("区市", "心理健康专兼职")) {
                    # 计算整个数据集的总体占比
                    n_total_overall <- sum(!is.na(dat[[stack_col]]))
                    
                    if (n_total_overall > 0) {
                        # 先计算所有类别的原始占比
                        pct_values_overall <- c()
                        for (stack_cat in stack_categories) {
                            n_count <- sum(count_eq_stack(dat[[stack_col]], stack_cat), na.rm = TRUE)
                            pct <- (n_count / n_total_overall) * 100
                            pct_values_overall <- c(pct_values_overall, pct)
                        }
                        
                        # 归一化确保总和为100%（避免浮点数精度问题）
                        if (sum(pct_values_overall) > 0) {
                            pct_values_overall <- pct_values_overall / sum(pct_values_overall) * 100
                        }
                        
                        # 保持原始精度，不进行四舍五入调整，确保数值准确
                        # 只在画图标签时进行格式化显示
                        for (j in seq_along(stack_categories)) {
                            result_table <- rbind(result_table, data.frame(
                                Y类别 = "青岛市",
                                stack类别 = stack_categories[j],
                                占比 = pct_values_overall[j]  # 使用原始值，不round
                            ))
                        }
                    }
                    
                    # 更新Y_categories，将"青岛市"放在最前面
                    Y_categories <- c("青岛市", Y_categories)
                }
            }
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_9_stack_bar_var_distribution.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 确保Y类别按照正确的顺序（用于Y轴）
        if (is_three_level_compare) {
            # 三级对比：固定顺序为 青岛市、区市、本校（从上到下）
            # 由于ggplot2的Y轴是从下到上，需要反转levels顺序
            Y_levels <- c("青岛市", school_district, "本校")
            Y_levels <- rev(Y_levels)  # 反转后：本校、区市、青岛市（factor levels从下到上）
            result_table$Y类别 <- factor(result_table$Y类别, levels = Y_levels)
            Y_categories <- rev(Y_levels)  # 用于循环处理，保持原始顺序
        } else {
            # 原有逻辑
            # 如果Y变量是"区市"，使用指定的levels顺序
            if (Y_var %in% c("区市", "心理健康专兼职")) {
                # 本校/区级数据中 Y 列常为 character；levels() 对非 factor 返回 NULL，会导致 Y_levels 过短、
                # factor() 把真实区名变成 NA，图缺失并触发 NAs introduced by coercion
                if (is.factor(dat[[Y_var]])) {
                    y_lev_from_dat <- levels(dat[[Y_var]])
                    y_lev_from_dat <- y_lev_from_dat[y_lev_from_dat %in% unique(as.character(dat[[Y_var]]))]
                } else {
                    y_lev_from_dat <- unique(dat[[Y_var]])
                    y_lev_from_dat <- y_lev_from_dat[!is.na(y_lev_from_dat)]
                    y_lev_from_dat <- sort(as.character(y_lev_from_dat))
                }
                Y_levels <- c("青岛市", y_lev_from_dat)
                # 只保留实际存在的类别
                Y_levels <- Y_levels[Y_levels %in% unique(result_table$Y类别)]
                # 反转levels顺序，使"青岛市"显示在最上面（ggplot2的Y轴从上到下对应levels从后往前）
                Y_levels <- rev(Y_levels)
                result_table$Y类别 <- factor(result_table$Y类别, levels = Y_levels)
                # 更新Y_categories为实际存在的类别（用于高度计算，保持原始顺序）
                Y_categories <- rev(Y_levels)
            } else {
                # 其他交叉或分类变量：先统一为字符再设 levels，只保留表中实际出现的取值，避免 factor 成 NA
                y_seen <- unique(as.character(result_table$Y类别))
                y_base <- as.character(Y_categories)
                y_base <- y_base[y_base %in% y_seen]
                if (length(y_base) == 0L) {
                    y_base <- sort(y_seen)
                }
                Y_categories <- rev(y_base)
                result_table$Y类别 <- factor(as.character(result_table$Y类别), levels = Y_categories)
            }
        }
        
        # 绘制累积条形图
        # 动态高度应该根据Y类别（柱子）的数量来计算
        n_y_categories <- length(unique(result_table$Y类别))
        # 3个bar高度为3，4个及以上需要更高
        if (is_three_level_compare) {
            plot_height <- 3  # 三级对比模式固定高度为4
        } else if (Y_var == "区市") {
            plot_height  <- 4

        } else if (n_y_categories <= 3) {
            plot_height <- 3
        } else {
            plot_height <- 3 + (n_y_categories - 3) * 0.4  # 4个及以上，每个增加0.5
        }
        
        # 确保stack类别按照正确的顺序（用于图例）
        result_table$stack类别 <- factor(result_table$stack类别, levels = stack_categories)
        # result_table <- result_table[order(result_table$Y类别, result_table$stack_categories), ]
        
        # 使用颜色映射函数（特殊处理"达标"和"不达标"）
        color_mapping_stack <- get_color_mapping(stack_categories, color_palette)
        
        # 计算每个标签的位置（用于处理重叠）
        # 注意：ggplot2的position_stack在水平条形图中是从右到左堆叠的（与factor levels顺序相反）
        # 所以我们需要反转stack_categories的顺序来计算位置
        reversed_stack_categories <- rev(stack_categories)
        
        # 对于每个Y类别，计算stack的累积位置
        result_table$cumsum_start <- 0
        result_table$cumsum_end <- 0
        result_table$label_x <- 0
        result_table$need_line <- FALSE
        result_table$line_x_start <- 0
        result_table$line_x_end <- 0
        
        for (y_cat in Y_categories) {
            y_data <- result_table[result_table$Y类别 == y_cat, ]
            # 按照反转后的顺序排序，以匹配实际的堆叠顺序
            y_data <- y_data[order(match(y_data$stack类别, reversed_stack_categories)), ]
            
            cumsum_val <- 0
            for (k in seq_len(nrow(y_data))) {
                y_data$cumsum_start[k] <- cumsum_val
                cumsum_val <- cumsum_val + y_data$占比[k]
                y_data$cumsum_end[k] <- cumsum_val
                y_data$label_x[k] <- (y_data$cumsum_start[k] + y_data$cumsum_end[k]) / 2
                
                # 判断是否需要拉线（占比<5）
                # 如果 hide_other_labels 为 TRUE 且 Y_var == "区市" 且 y_cat != target_district，则不需要拉线
                # 注意：在三级对比模式下，Y_var可能不存在
                if (hide_other_labels && !is.null(target_district) && exists("Y_var") && Y_var == "区市" && y_cat != target_district) {
                    y_data$need_line[k] <- FALSE
                } else if (y_data$占比[k] < 5) {
                    y_data$need_line[k] <- TRUE
                    # 标签位置向右移动，从segment中心拉线
                    y_data$line_x_start[k] <- y_data$label_x[k]
                    y_data$line_x_end[k] <- y_data$label_x[k] + 3  # 向右移动3个单位
                } else {
                    y_data$need_line[k] <- FALSE
                }
            }
            
            # 处理相邻多个小标签的情况，错开x位置
            if (sum(y_data$need_line) > 1) {
                small_labels <- which(y_data$need_line)
                # 交替错开x位置，避免重叠
                for (idx in seq_along(small_labels)) {
                    k <- small_labels[idx]
                    # 根据索引错开位置：第1个+3，第2个+5，第3个+7，以此类推
                    offset <- 1 + (idx - 1) * 4
                    y_data$line_x_end[k] <- y_data$label_x[k] + offset
                }
            }
            
            # 更新result_table
            result_table[result_table$Y类别 == y_cat, ] <- y_data
        }
        # Y轴显示Y类别（柱子），X轴显示占比（0-100%），stack类别作为fill
        p <- ggplot(result_table, aes(x = 占比, y = Y类别, fill = stack类别)) +
            geom_bar(stat = "identity", position = "stack", width = 0.4) +
            scale_fill_manual(values = color_mapping_stack, name = "", breaks = stack_categories)
        
        # 添加拉线（仅对占比<5的标签，终点向上移动0.3避免遮挡）
        # 如果 hide_other_labels 为 TRUE 且 Y_var == "区市"，只显示 target_district 的拉线
        if (hide_other_labels && !is.null(target_district)) {
            # 注意：在三级对比模式下，Y_var可能不存在，需要检查
            if (exists("Y_var") && Y_var == "区市") {
                line_data <- result_table[result_table$need_line & result_table$Y类别 == target_district, ]
            } else {
                line_data <- result_table[result_table$need_line, ]
            }
        } else {
            line_data <- result_table[result_table$need_line, ]
        }
        
        # 三级对比模式：只保留"本校"的拉线
        if (is_three_level_compare) {
            line_data <- line_data[line_data$Y类别 == "本校", ]
        }
        
        if (nrow(line_data) > 0) {
            # 计算调整后的y位置（终点向上移动0.3）
            # 将factor转换为数字，然后向上移动
            line_data$y_start <- as.numeric(line_data$Y类别)
            line_data$y_end <- as.numeric(line_data$Y类别) + 0.3  # 终点向上移动0.3
            
            p <- p + geom_segment(data = line_data,
                                 aes(x = line_x_start, xend = line_x_end, 
                                     y = y_start, yend = y_end),
                                 inherit.aes = FALSE,
                                 color = "black",
                                 linewidth = 0.3)
        }
        
        # 添加标签：需要拉线的和不需要拉线的分开处理
        # 不需要拉线的标签（正常位置，使用position_stack）
        result_table$Lable <- ""
        
        # 如果 hide_other_labels 为 TRUE 且 Y_var == "区市"，只显示 target_district 的标签
        if (hide_other_labels && !is.null(target_district)) {
            # 注意：在三级对比模式下，Y_var可能不存在，需要检查
            if (exists("Y_var") && Y_var == "区市") {
                # 只对 target_district 的标签赋值
                result_table$Lable[!result_table$need_line & result_table$Y类别 == target_district] <- 
                    paste0(round(result_table$占比[!result_table$need_line & result_table$Y类别 == target_district], 1), "%")
            } else {
                result_table$Lable[!result_table$need_line] <- paste0(round(result_table$占比[!result_table$need_line], 1), "%")
            }
        } else {
            result_table$Lable[!result_table$need_line] <- paste0(round(result_table$占比[!result_table$need_line], 1), "%")
        }
        
        # 三级对比模式：只显示"本校"的标签
        if (is_three_level_compare) {
            result_table$Lable[!result_table$need_line & result_table$Y类别 != "本校"] <- ""
            # 同时处理需要拉线的标签
            result_table$Lable[result_table$need_line & result_table$Y类别 != "本校"] <- ""
        }

        if (nrow(result_table[!result_table$need_line & result_table$Lable != "", ]) > 0) {
            # 使用label_x来定位标签，而不是position_stack
            # 因为position_stack会根据占比值自动计算位置，但我们需要使用我们计算的label_x位置
            label_data <- result_table[!result_table$need_line & result_table$Lable != "", ]
            p <- p + geom_text(data = label_data,
                             aes(x = label_x, y = Y类别, label = Lable),
                             inherit.aes = FALSE,
                             hjust = 0.5,
                             vjust = 0.5,
                             size = 3)
        }
        
        # 需要拉线的标签（放在拉线末端，向上移动0.3避免遮挡）
        if (nrow(line_data) > 0) {
            # 为拉线标签准备label列
            line_data$label_text <- paste0(round(line_data$占比, 1), "%")
            # 三级对比模式：只显示"本校"的标签
            if (is_three_level_compare) {
                line_data$label_text[line_data$Y类别 != "本校"] <- ""
            }
            p <- p + geom_text(data = line_data,
                             aes(x = line_x_end, y = y_end, label = label_text),
                             inherit.aes = FALSE,
                             hjust = 0.5,
                             vjust = -0.1,
                             size = 2.7)
        }
        

        # 计算图例需要的行数（5个类别，如果字符较多可以设置为2-3行）
        n_legend_items <- length(stack_categories)
        n_string_length <- mean(nchar(stack_categories))
        
        legend_nrow <- if (n_legend_items <= 4 & n_string_length <= 8) {
            1
        } else if (n_legend_items <= 6 & n_string_length <= 9) {
            2
        } else if (n_string_length > 13){
            4
        } else {
            3
        }
        
        p <- p +
            labs(caption = ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题),
                 x = "", y = "") +
            scale_x_continuous(labels = function(x) paste0(x, "%"), limits = c(0, 109), breaks = seq(0, 100, by = 10), expand = c(0, 0)) +
            guides(fill = guide_legend(nrow = legend_nrow, byrow = TRUE)) +  # 控制图例行数，byrow=TRUE表示按行填充
            theme_minimal() +
            theme(legend.position = "bottom",
                  plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                  plot.caption.position = "plot",  # 相对于整个绘图区域居中
                  legend.key.height = unit(0.5, "lines"),  # 图例方块高度为原来的1/2
                  legend.key.width = unit(1, "lines"),  # 图例方块宽度保持不变
                  panel.grid = element_blank(),  # 去掉所有背景网格线
                  axis.line = element_line(color = "black"))  # 添加X轴和Y轴线
        
        # 存储高度信息
        attr(p, "plot_height") <- plot_height
        
        return(list(table = result_table, plot = p))
    }, error = function(e) {
        warning(paste("第", i, "行：stack_bar_var_distribution函数执行失败：", e$message))
        NULL  # 直接返回NULL，不使用return()
    })
}

# 9.4. stack_bar_change_y函数（带对齐功能的累积条形图）
generate_stack_bar_change_y <- function(dat, index_report_row, index_item, i, color_palette, 
                                        is_three_level_compare = FALSE, dat_qd = NULL, dat_dist = NULL, school_name = NULL) {
    tryCatch({
        # 获取报告维度（用于确定stack列）
        dim_or_item <- index_report_row$dim_or_item
        if (is.na(dim_or_item) || dim_or_item == "") {
            warning(paste("第", i, "行：dim_or_item为空"))
            return(NULL)
        }
        
        dim_or_item_value <- index_report_row$报告维度
        if (is.na(dim_or_item_value) || dim_or_item_value == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 确定用于stack的分类变量
        if (dim_or_item == "dim") {
            stack_col <- paste0(dim_or_item_value, "_Class")
        } else {
            stack_col <- dim_or_item_value
        }
        
        if (!stack_col %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到stack变量", stack_col))
            return(NULL)
        }
        
        # 根据数据表对应过滤index_item
        index_item_filtered <- filter_index_item_by_data_table(index_item, index_report_row)
        
        # 获取stack变量的类别（用于fill）
        if (dim_or_item == "dim") {
            item_row <- index_item_filtered %>% filter(报告维度 == dim_or_item_value) %>% slice(1)
            if (nrow(item_row) == 0) {
                warning(paste("第", i, "行：未找到维度", dim_or_item_value, "的信息"))
                return(NULL)
            }
            stack_categories <- c()
            for (j in 1:10) {
                col_name <- paste0("报告维度分类名", j)
                if (col_name %in% colnames(index_item_filtered)) {
                    cat_val <- item_row[[col_name]]
                    if (!is.na(cat_val) && cat_val != "") {
                        stack_categories <- c(stack_categories, as.character(cat_val))
                    }
                }
            }
            # 不按数据中是否出现过滤：缺失等级的学生为 0%，图例仍保留 index 中的全部类别
        } else if (dim_or_item == "item") {
            item_row <- index_item_filtered %>% filter(题目列名 == dim_or_item_value) %>% slice(1)
            if (nrow(item_row) == 0) {
                warning(paste("第", i, "行：未找到题目", dim_or_item_value, "的信息"))
                return(NULL)
            }
            options_str <- item_row$选项
            if (is.na(options_str) || options_str == "") {
                warning(paste("第", i, "行：题目", dim_or_item_value, "的选项为空"))
                return(NULL)
            }
            stack_categories <- strsplit(options_str, "//C//", fixed = TRUE)[[1]]
            stack_categories <- trimws(stack_categories)
            # 不按数据中是否出现过滤：缺失等级数据中为 0%，图例仍保留全部选项
        } else if (dim_or_item == "basic") {
            if (is.factor(dat[[stack_col]])) {
                stack_categories <- levels(dat[[stack_col]])
            } else {
                stack_categories <- unique(dat[[stack_col]])
                stack_categories <- stack_categories[!is.na(stack_categories)]
                stack_categories <- as.character(stack_categories)
            }
        }
        
        # 语文学业（及同命名）四水平：即使某档在数据中无人，仍固定为四个等级供绘图与图例
        ach_levels_stack_bar <- c("水平Ⅳ", "水平Ⅲ", "水平II", "水平I")
        if (length(stack_categories) > 0 && all(stack_categories %in% ach_levels_stack_bar)) {
            stack_categories <- ach_levels_stack_bar
        }
        
        # 检查stack_categories是否有足够的类别
        if (length(stack_categories) < 2) {
            warning(paste("第", i, "行：stack类别数量少于2，无法设置对齐点"))
            return(NULL)
        }
        
        # 获取对齐分界点信息（例如："水平I|水平II"）
        align_boundary <- index_report_row$sum_indices
        
        # 如果对齐分界点为空，使用默认值：levels的第一个和第二个类别之间
        if (is.null(align_boundary) || is.na(align_boundary) || align_boundary == "") {
            left_category <- stack_categories[1]
            right_category <- stack_categories[2]
            cat("第", i, "行：对齐分界点为空，使用默认值：", left_category, "|", right_category, "\n")
        } else {
            # 解析对齐分界点（假设格式为"类别1|类别2"）
            boundary_parts <- strsplit(align_boundary, "|", fixed = TRUE)[[1]]
            if (length(boundary_parts) != 2) {
                warning(paste("第", i, "行：对齐分界点格式错误，应为'类别1|类别2'"))
                return(NULL)
            }
            left_category <- trimws(boundary_parts[1])
            right_category <- trimws(boundary_parts[2])
        }
        
        # 验证对齐分界点的类别是否存在于stack_categories中
        if (!left_category %in% stack_categories || !right_category %in% stack_categories) {
            warning(paste("第", i, "行：对齐分界点的类别不在stack类别中"))
            return(NULL)
        }
        
        # 三级对比逻辑
        if (is_three_level_compare) {
            # 检查必要的数据是否提供
            if (is.null(dat_qd) || is.null(dat_dist) || is.null(school_name)) {
                warning(paste("第", i, "行：三级对比模式需要提供dat_qd、dat_dist和school_name参数"))
                return(NULL)
            }
            
            # 检查stack_col是否在所有数据中存在
            if (!stack_col %in% colnames(dat_qd) || !stack_col %in% colnames(dat_dist) || !stack_col %in% colnames(dat)) {
                warning(paste("第", i, "行：三级对比模式中，stack_col", stack_col, "不在所有数据中存在"))
                return(NULL)
            }
            
            # 获取学校所在区市（从dat_dist中获取，因为dat_dist已经过滤了该区市的数据）
            if ("区市" %in% colnames(dat_dist) && nrow(dat_dist) > 0) {
                school_district <- as.character(unique(dat_dist$区市)[1])
            } else {
                warning(paste("第", i, "行：无法从dat_dist中确定学校所在的区市"))
                return(NULL)
            }
            
            # 三级对比：Y类别固定为"青岛市"、"区市"、"本校"
            Y_categories <- c("青岛市", school_district, "本校")
            
            # 计算交叉表
            result_table <- data.frame(
                Y类别 = character(),
                stack类别 = character(),
                占比 = numeric(),
                stringsAsFactors = FALSE
            )
            
            # 对于每个Y类别，计算stack类别的占比
            for (y_cat in Y_categories) {
                if (y_cat == "青岛市") {
                    dat_subset <- dat_qd
                } else if (y_cat == school_district) {
                    dat_subset <- dat_dist
                } else if (y_cat == "本校") {
                    dat_subset <- dat
                } else {
                    next
                }
                
                n_total <- sum(!is.na(dat_subset[[stack_col]]))
                
                if (n_total == 0) {
                    next
                }
                
                # 先计算所有类别的原始占比
                pct_values <- c()
                for (stack_cat in stack_categories) {
                    n_count <- sum(dat_subset[[stack_col]] == stack_cat, na.rm = TRUE)
                    pct <- (n_count / n_total) * 100
                    pct_values <- c(pct_values, pct)
                }
                
                # 归一化确保总和为100%（避免浮点数精度问题）
                if (sum(pct_values) > 0) {
                    pct_values <- pct_values / sum(pct_values) * 100
                }
                
                # 添加到结果表（保持原始精度）
                for (j in seq_along(stack_categories)) {
                    result_table <- rbind(result_table, data.frame(
                        Y类别 = y_cat,
                        stack类别 = stack_categories[j],
                        占比 = pct_values[j]  # 使用原始值，不round
                    ))
                }
            }
        } else {
            # 原有逻辑
            # 确定Y轴变量
            Y_var <- index_report_row$交叉或分类变量
            if (is.na(Y_var) || Y_var == "") {
                warning(paste("第", i, "行：交叉或分类变量为空"))
                return(NULL)
            }
            
            if (Y_var %in% basic_vars) {
                Y_col <- Y_var
            } else {
                Y_col <- paste0(Y_var, "_Class")
            }
            
            if (!Y_col %in% colnames(dat)) {
                warning(paste("第", i, "行：未找到Y轴变量", Y_col))
                return(NULL)
            }
            
            # 计算交叉表
            result_table <- data.frame(
                Y类别 = character(),
                stack类别 = character(),
                占比 = numeric(),
                stringsAsFactors = FALSE
            )
            
            # 获取Y变量的所有类别
            if (is.factor(dat[[Y_col]])) {
                Y_categories <- levels(dat[[Y_col]])
                Y_categories <- Y_categories[Y_categories %in% unique(dat[[Y_col]])]
            } else {
                Y_categories <- unique(dat[[Y_col]])
                Y_categories <- Y_categories[!is.na(Y_categories)]
                Y_categories <- sort(Y_categories)
            }
            
            # 对于每个Y类别，计算stack类别的占比
            for (y_cat in Y_categories) {
                dat_subset <- dat[dat[[Y_col]] == y_cat & !is.na(dat[[Y_col]]), ]
                n_total <- sum(!is.na(dat_subset[[stack_col]]))
                
                if (n_total == 0) {
                    next
                }
                
                pct_values <- c()
                for (stack_cat in stack_categories) {
                    n_count <- sum(dat_subset[[stack_col]] == stack_cat, na.rm = TRUE)
                    pct <- (n_count / n_total) * 100
                    pct_values <- c(pct_values, pct)
                }
                
                if (sum(pct_values) > 0) {
                    pct_values <- pct_values / sum(pct_values) * 100
                }
                
                # 保持原始精度，不进行四舍五入调整，确保数值准确
                # 只在画图标签时进行格式化显示
                for (j in seq_along(stack_categories)) {
                    result_table <- rbind(result_table, data.frame(
                        Y类别 = y_cat,
                        stack类别 = stack_categories[j],
                        占比 = pct_values[j]  # 使用原始值，不round
                    ))
                }
            }
            
            # 如果Y变量是"区市"，需要添加总体（青岛市）的计算
            if (Y_var == "区市") {
                n_total_overall <- sum(!is.na(dat[[stack_col]]))
                
                if (n_total_overall > 0) {
                    pct_values_overall <- c()
                    for (stack_cat in stack_categories) {
                        n_count <- sum(dat[[stack_col]] == stack_cat, na.rm = TRUE)
                        pct <- (n_count / n_total_overall) * 100
                        pct_values_overall <- c(pct_values_overall, pct)
                    }
                    
                    if (sum(pct_values_overall) > 0) {
                        pct_values_overall <- pct_values_overall / sum(pct_values_overall) * 100
                    }
                    
                    # 保持原始精度，不进行四舍五入调整，确保数值准确
                    # 只在画图标签时进行格式化显示
                    for (j in seq_along(stack_categories)) {
                        result_table <- rbind(result_table, data.frame(
                            Y类别 = "青岛市",
                            stack类别 = stack_categories[j],
                            占比 = pct_values_overall[j]  # 使用原始值，不round
                        ))
                    }
                }
                
                Y_categories <- c("青岛市", Y_categories)
            }
        }
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_9_stack_bar_change_y.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 确保Y类别按照正确的顺序
        if (is_three_level_compare) {
            # 三级对比：Y类别固定为"青岛市"、"区市"、"本校"
            Y_levels <- Y_categories
            # 不反转，保持 [青岛市, 区市, 本校] 的顺序
            # 因为后续会使用 trans = "reverse"，这样青岛市（levels[1]）会显示在最上面
            result_table$Y类别 <- factor(result_table$Y类别, levels = Y_levels)
            # 重要：Y_categories 必须与 factor levels 的顺序一致，用于后续循环和绘图
            Y_categories <- Y_levels  # 使用与 factor levels 相同的顺序
        } else if (exists("Y_var") && Y_var == "区市") {
            Y_levels <- c("青岛市", levels(dat$区市))
            Y_levels <- Y_levels[Y_levels %in% unique(result_table$Y类别)]
            # 不反转，保持 [青岛市, 局属学校, ..., 莱西市] 的顺序
            # 因为后续会使用 trans = "reverse"，这样青岛市（levels[1]）会显示在最上面
            result_table$Y类别 <- factor(result_table$Y类别, levels = Y_levels)
            # 重要：Y_categories 必须与 factor levels 的顺序一致，用于后续循环和绘图
            Y_categories <- Y_levels  # 使用与 factor levels 相同的顺序
        } else {
            Y_categories <- rev(Y_categories)
            result_table$Y类别 <- factor(result_table$Y类别, levels = Y_categories)
        }
        
        # 确保stack类别按照正确的顺序
        result_table$stack类别 <- factor(result_table$stack类别, levels = stack_categories)
        
        # 重要：按照factor levels的顺序重新排序result_table，确保数据顺序与factor levels一致
        # 先按Y类别排序（按照factor levels的顺序），再按stack类别排序（按照factor levels的顺序）
        result_table <- result_table[order(as.numeric(result_table$Y类别), as.numeric(result_table$stack类别)), ]
        
        # 计算对齐点：找到left_category和right_category在stack_categories中的位置
        left_idx <- which(stack_categories == left_category)
        right_idx <- which(stack_categories == right_category)
        
        if (length(left_idx) == 0 || length(right_idx) == 0 || left_idx >= right_idx) {
            warning(paste("第", i, "行：对齐分界点的类别顺序错误"))
            return(NULL)
        }
        
        # 计算每个Y类别的对齐点位置（左侧累积占比）
        # 对齐点左侧的类别向左累积，右侧的类别向右累积
        result_table$align_point_left <- 0  # 对齐点左侧的累积占比
        result_table$align_point_right <- 0  # 对齐点右侧的累积占比
        result_table$x_start <- 0  # 条形图起始位置（相对于对齐点）
        result_table$x_end <- 0    # 条形图结束位置（相对于对齐点）
        
        for (y_cat in Y_categories) {
            y_data <- result_table[result_table$Y类别 == y_cat, ]
            
            # 计算对齐点左侧的累积占比（向左扩展）
            left_sum <- 0
            for (k in 1:(left_idx)) {
                cat_name <- stack_categories[k]
                cat_pct <- y_data$占比[y_data$stack类别 == cat_name]
                if (length(cat_pct) > 0) {
                    left_sum <- left_sum + cat_pct[1]
                }
            }
            
            # 计算对齐点右侧的累积占比（向右扩展）
            right_sum <- 0
            for (k in (right_idx):length(stack_categories)) {
                cat_name <- stack_categories[k]
                cat_pct <- y_data$占比[y_data$stack类别 == cat_name]
                if (length(cat_pct) > 0) {
                    right_sum <- right_sum + cat_pct[1]
                }
            }
            
            # 更新result_table中的对齐点信息
            result_table$align_point_left[result_table$Y类别 == y_cat] <- left_sum
            result_table$align_point_right[result_table$Y类别 == y_cat] <- right_sum
            
            # 计算每个stack类别的x位置（相对于对齐点）
            # 对齐点在x=0处，左侧类别向左累积（负值），右侧类别向右累积（正值）
            # 左侧沿中线向外顺序改为：按 stack 序号从 left_idx→1（即先画靠中线的 left_category，
            # 再往外），使 index 中 II、Ⅲ、Ⅳ 的条形视觉顺序为 Ⅳ（最左）…Ⅲ…II（贴中线）
            cumsum_left <- 0
            cumsum_right <- 0  # 从对齐点（x=0）开始向右累积
            
            for (k in left_idx:1) {
                cat_name <- stack_categories[k]
                cat_pct <- y_data$占比[y_data$stack类别 == cat_name]
                if (length(cat_pct) > 0) {
                    pct_val <- cat_pct[1]
                    result_table$x_start[result_table$Y类别 == y_cat & result_table$stack类别 == cat_name] <- -cumsum_left - pct_val
                    result_table$x_end[result_table$Y类别 == y_cat & result_table$stack类别 == cat_name] <- -cumsum_left
                    cumsum_left <- cumsum_left + pct_val
                }
            }
            if (left_idx < length(stack_categories)) {
                for (k in (left_idx + 1):length(stack_categories)) {
                    cat_name <- stack_categories[k]
                    cat_pct <- y_data$占比[y_data$stack类别 == cat_name]
                    if (length(cat_pct) > 0) {
                        pct_val <- cat_pct[1]
                        result_table$x_start[result_table$Y类别 == y_cat & result_table$stack类别 == cat_name] <- cumsum_right
                        result_table$x_end[result_table$Y类别 == y_cat & result_table$stack类别 == cat_name] <- cumsum_right + pct_val
                        cumsum_right <- cumsum_right + pct_val
                    }
                }
            }
        }
        
        # 计算动态高度
        n_y_categories <- length(unique(result_table$Y类别))
        if (n_y_categories <= 3) {
            plot_height <- 3
        } else {
            plot_height <- 3 + (n_y_categories - 3) * 0.4
        }
        
        # 使用颜色映射函数（反转颜色序列）
        color_mapping_stack <- get_color_mapping(stack_categories, color_palette, reverse = TRUE)
        
        # 计算标签位置
        result_table$label_x <- (result_table$x_start + result_table$x_end) / 2
        result_table$need_line <- result_table$占比 < 5
        result_table$line_x_start <- result_table$label_x
        result_table$line_x_end <- result_table$label_x + ifelse(result_table$need_line, 3, 0)
        
        # 处理相邻多个小标签的情况
        for (y_cat in Y_categories) {
            y_data <- result_table[result_table$Y类别 == y_cat, ]
            if (sum(y_data$need_line) > 1) {
                small_labels <- which(y_data$need_line)
                for (idx in seq_along(small_labels)) {
                    k <- small_labels[idx]
                    offset <- 1 + (idx - 1) * 4
                    result_table$line_x_end[result_table$Y类别 == y_cat & result_table$need_line][idx] <- 
                        result_table$label_x[result_table$Y类别 == y_cat & result_table$need_line][idx] + offset
                }
            }
        }
        
        # 计算X轴范围：左侧仍按数据对称留白（与原先一致），右侧上限固定为 65（百分比刻度）
        x_min <- min(result_table$x_start)
        x_max <- max(result_table$x_end)
        x_range <- max(abs(x_min), abs(x_max))
        x_left <- -x_range - 10
        x_right_max <- 65
        x_limits <- c(x_left, x_right_max)
        
        # 绘制累积条形图（使用geom_rect而不是geom_bar，因为需要自定义位置）
        p <- ggplot() +
            geom_rect(data = result_table,
                     aes(xmin = x_start, xmax = x_end, ymin = as.numeric(Y类别) - 0.2, 
                         ymax = as.numeric(Y类别) + 0.2, fill = stack类别),
                     inherit.aes = FALSE) +
            scale_fill_manual(values = color_mapping_stack, name = "", breaks = stack_categories) +
            geom_vline(xintercept = 0, linetype = "solid", color = "black", linewidth = 0.5)  # 对齐线
        
        # 添加拉线
        line_data <- result_table[result_table$need_line, ]
        
        # 三级对比模式：只保留"本校"的拉线
        if (is_three_level_compare) {
            line_data <- line_data[line_data$Y类别 == "本校", ]
        }
        
        if (nrow(line_data) > 0) {
            line_data$y_start <- as.numeric(line_data$Y类别)
            # 因为Y轴使用了trans = "reverse"，所以拉线方向需要反转（减而不是加）
            line_data$y_end <- as.numeric(line_data$Y类别) - 0.3
            
            p <- p + geom_segment(data = line_data,
                                 aes(x = line_x_start, xend = line_x_end, 
                                     y = y_start, yend = y_end),
                                 inherit.aes = FALSE,
                                 color = "black",
                                 linewidth = 0.3)
        }
        
        # 添加标签
        result_table$Lable <- ""
        result_table$Lable[!result_table$need_line] <- paste0(round(result_table$占比[!result_table$need_line], 1), "%")
        
        # 三级对比模式：只显示"本校"的标签
        if (is_three_level_compare) {
            result_table$Lable[!result_table$need_line & result_table$Y类别 != "本校"] <- ""
            # 同时处理需要拉线的标签
            result_table$Lable[result_table$need_line & result_table$Y类别 != "本校"] <- ""
        }
        
        if (nrow(result_table[!result_table$need_line, ]) > 0) {
            p <- p + geom_text(data = result_table[!result_table$need_line, ],
                             aes(x = label_x, y = as.numeric(Y类别), label = Lable),
                             inherit.aes = FALSE,
                             size = 3)
        }
        
        if (nrow(line_data) > 0) {
            # 为拉线标签准备label列
            line_data$label_text <- paste0(round(line_data$占比, 1), "%")
            # 三级对比模式：只显示"本校"的标签
            if (is_three_level_compare) {
                line_data$label_text[line_data$Y类别 != "本校"] <- ""
            }
            p <- p + geom_text(data = line_data,
                             aes(x = line_x_end, y = y_end, label = label_text),
                             inherit.aes = FALSE,
                             hjust = 0.5,
                             vjust = -0.1,
                             size = 2.7)
        }
        
        # 图例固定一行
        legend_nrow <- 1
        
        # X轴刻度：0 左侧每 20 一格至 x_left，右侧 0–65 每 20 一格（均在 limits 内）
        x_breaks <- unique(sort(c(seq(0, x_limits[1], by = -20), seq(0, x_limits[2], by = 20))))
        x_breaks <- x_breaks[x_breaks >= x_limits[1] & x_breaks <= x_limits[2]]
        x_labels <- paste0(abs(x_breaks), "%")
        
        p <- p +
            labs(caption = ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题),
                 x = "", y = "") +
            scale_x_continuous(labels = x_labels, limits = x_limits, breaks = x_breaks, expand = c(0, 0)) +
            scale_y_continuous(breaks = 1:length(Y_categories), labels = Y_categories, expand = c(0.1, 0.1),
                             trans = "reverse") +
            guides(fill = guide_legend(nrow = legend_nrow, byrow = TRUE)) +
            theme_minimal() +
            theme(legend.position = "bottom",
                  plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                  plot.caption.position = "plot",
                  legend.key.height = unit(0.5, "lines"),
                  legend.key.width = unit(1, "lines"),
                  panel.grid = element_blank(),
                  axis.line = element_line(color = "black"))
        
        attr(p, "plot_height") <- plot_height
        
        # 调试信息：记录生成时的数据快照（输出完整的标签数据）
        cat("【生成时】第", i, "行：stack_bar_change_y数据快照\n")
        cat("  table行数:", nrow(result_table), "\n")
        cat("  完整数据（Y类别 | stack类别 | 占比 | Lable）：\n")
        for (r in 1:nrow(result_table)) {
            cat("    行", r, ":", as.character(result_table$Y类别[r]), "|", 
                as.character(result_table$stack类别[r]), "|", 
                result_table$占比[r], "|", 
                ifelse("Lable" %in% colnames(result_table), result_table$Lable[r], ""), "\n")
        }
        # 将数据快照存储到plot对象的属性中
        attr(p, "data_snapshot") <- list(
            nrow = nrow(result_table),
            Y_categories = as.character(unique(result_table$Y类别)),
            full_table = result_table
        )
        
        # 返回与其他generate函数一致的格式：list(table = result_table, plot = p)
        # 注意：table已保存为CSV，但为了格式一致性仍包含在返回值中
        return(list(table = result_table, plot = p))
    }, error = function(e) {
        warning(paste("第", i, "行：stack_bar_change_y函数执行失败：", e$message))
        NULL
    })
}

# 9.5. stack_bar_subdim函数
generate_stack_bar_subdim <- function(dat, index_report_row, index_item, i, color_palette) {
    tryCatch({
        # 获取报告维度
        dim <- index_report_row$报告维度
        if (is.na(dim) || dim == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 根据数据表对应过滤index_item
        index_item_filtered <- filter_index_item_by_data_table(index_item, index_report_row)
        
        # 在index_item中找到该维度的所有唯一子维度
        subdims <- index_item_filtered %>%
            filter(报告维度 == dim, !is.na(子维度)) %>%
            pull(子维度) %>%
            unique()
        
        if (length(subdims) == 0) {
            warning(paste("第", i, "行：维度", dim, "未找到子维度"))
            return(NULL)
        }
        
        # 构建Class列名
        class_cols <- paste0(subdims, "_Class")
        
        # 检查哪些列存在
        existing_cols <- class_cols[class_cols %in% colnames(dat)]
        if (length(existing_cols) == 0) {
            warning(paste("第", i, "行：未找到任何子维度Class列"))
            return(NULL)
        }
        
        # 获取stack类别（从第一个子维度的Class列获取，所有子维度的类别名相同）
        first_col <- existing_cols[1]
        if (is.factor(dat[[first_col]])) {
            stack_categories <- levels(dat[[first_col]])
            stack_categories <- stack_categories[stack_categories %in% unique(dat[[first_col]])]
        } else {
            stack_categories <- unique(dat[[first_col]])
            stack_categories <- stack_categories[!is.na(stack_categories)]
            stack_categories <- as.character(stack_categories)
        }
        
        # 计算交叉表
        # Y轴显示子维度，stack显示stack类别（fill）
        result_table <- data.frame(
            Y类别 = character(),
            stack类别 = character(),
            占比 = numeric(),
            stringsAsFactors = FALSE
        )
        
        # 对于每个子维度，直接计算整个数据集中该子维度的Class变量占比
        for (subdim in subdims) {
            class_col <- paste0(subdim, "_Class")
            if (!class_col %in% colnames(dat)) {
                next
            }
            
            n_total <- sum(!is.na(dat[[class_col]]))
            if (n_total == 0) {
                next
            }
            
            # 计算所有类别的原始占比
            pct_values <- c()
            for (stack_cat in stack_categories) {
                n_count <- sum(dat[[class_col]] == stack_cat, na.rm = TRUE)
                pct <- (n_count / n_total) * 100
                pct_values <- c(pct_values, pct)
            }
            
            # 归一化确保总和为100%
            if (sum(pct_values) > 0) {
                pct_values <- pct_values / sum(pct_values) * 100
            }
            
            # 四舍五入后，调整最后一个类别使总和为100%
            pct_rounded <- round(pct_values, 1)
            if (abs(sum(pct_rounded) - 100) > 0.01) {
                diff <- 100 - sum(pct_rounded[-length(pct_rounded)])
                pct_rounded[length(pct_rounded)] <- diff
            }
            
            # 添加到结果表
            for (j in seq_along(stack_categories)) {
                result_table <- rbind(result_table, data.frame(
                    Y类别 = subdim,
                    stack类别 = stack_categories[j],
                    占比 = pct_rounded[j]
                ))
            }
        }
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_9.5_stack_bar_subdim.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 确保Y类别按照正确的顺序（用于Y轴）
        # Y类别是子维度，需要保持原始顺序
        Y_levels <- unique(result_table$Y类别)
        # 反转顺序，使第一个子维度显示在最上面
        Y_levels <- rev(Y_levels)
        result_table$Y类别 <- factor(result_table$Y类别, levels = Y_levels)
        
        # 绘制累积条形图
        # 动态高度应该根据Y类别（柱子）的数量来计算
        n_y_categories <- length(unique(result_table$Y类别))
        if (n_y_categories <= 3) {
            plot_height <- 3
        } else {
            plot_height <- 3 + (n_y_categories - 3) * 0.4
        }
        
        # 确保stack类别按照正确的顺序（用于图例）
        result_table$stack类别 <- factor(result_table$stack类别, levels = stack_categories)
        
        # 使用颜色映射函数
        color_mapping_stack <- get_color_mapping(stack_categories, color_palette)
        
        # 计算每个标签的位置（用于处理重叠）
        reversed_stack_categories <- rev(stack_categories)
        
        # 对于每个Y类别（子维度），计算stack的累积位置
        result_table$cumsum_start <- 0
        result_table$cumsum_end <- 0
        result_table$label_x <- 0
        result_table$need_line <- FALSE
        result_table$line_x_start <- 0
        result_table$line_x_end <- 0
        
        for (y_cat in Y_levels) {
            y_data <- result_table[result_table$Y类别 == y_cat, ]
            y_data <- y_data[order(match(y_data$stack类别, reversed_stack_categories)), ]
            
            cumsum_val <- 0
            for (k in seq_len(nrow(y_data))) {
                y_data$cumsum_start[k] <- cumsum_val
                cumsum_val <- cumsum_val + y_data$占比[k]
                y_data$cumsum_end[k] <- cumsum_val
                y_data$label_x[k] <- (y_data$cumsum_start[k] + y_data$cumsum_end[k]) / 2
                
                # 判断是否需要拉线（占比<5）
                if (y_data$占比[k] < 5) {
                    y_data$need_line[k] <- TRUE
                    y_data$line_x_start[k] <- y_data$label_x[k]
                    y_data$line_x_end[k] <- y_data$label_x[k] + 3
                }
            }
            
            # 处理相邻多个小标签的情况，错开x位置
            if (sum(y_data$need_line) > 1) {
                small_labels <- which(y_data$need_line)
                for (idx in seq_along(small_labels)) {
                    k <- small_labels[idx]
                    offset <- 1 + (idx - 1) * 4
                    y_data$line_x_end[k] <- y_data$label_x[k] + offset
                }
            }
            
            # 更新result_table
            result_table[result_table$Y类别 == y_cat, ] <- y_data
        }
        
        # Y轴显示Y类别（子维度），X轴显示占比（0-100%），stack类别作为fill
        p <- ggplot(result_table, aes(x = 占比, y = Y类别, fill = stack类别)) +
            geom_bar(stat = "identity", position = "stack", width = 0.4) +
            scale_fill_manual(values = color_mapping_stack, name = "", breaks = stack_categories)
        
        # 添加拉线（仅对占比<5的标签）
        line_data <- result_table[result_table$need_line, ]
        if (nrow(line_data) > 0) {
            line_data$y_start <- as.numeric(line_data$Y类别)
            line_data$y_end <- as.numeric(line_data$Y类别) + 0.3
            
            p <- p + geom_segment(data = line_data,
                                 aes(x = line_x_start, xend = line_x_end, 
                                     y = y_start, yend = y_end),
                                 inherit.aes = FALSE,
                                 color = "black",
                                 linewidth = 0.3)
        }
        
        # 添加标签
        result_table$Lable <- ""
        result_table$Lable[!result_table$need_line] <- paste0(round(result_table$占比[!result_table$need_line], 1), "%")
        
        if (nrow(result_table[!result_table$need_line, ]) > 0) {
            p <- p + geom_text(data = result_table,
                             aes(x = 占比, y = Y类别, label = Lable),
                             inherit.aes = FALSE,
                             position = position_stack(vjust = 0.5),
                             size = 3)
        }
        
        # 需要拉线的标签
        if (nrow(line_data) > 0) {
            p <- p + geom_text(data = line_data,
                             aes(x = line_x_end, y = y_end, label = paste0(round(占比, 1), "%")),
                             inherit.aes = FALSE,
                             hjust = 0.5,
                             vjust = -0.1,
                             size = 2.7)
        }
        
        # 计算图例需要的行数
        n_legend_items <- length(stack_categories)
        n_string_length <- sum(nchar(stack_categories))
        
        legend_nrow <- if (n_legend_items <= 3) {
            1
        } else if (n_legend_items <= 6 & n_string_length <= 50) {
            2
        } else {
            3
        }
        
        p <- p +
            labs(caption = ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题),
                 x = "", y = "") +
            scale_x_continuous(labels = function(x) paste0(x, "%"), limits = c(0, 109), breaks = seq(0, 100, by = 10), expand = c(0, 0)) +
            guides(fill = guide_legend(nrow = legend_nrow, byrow = TRUE)) +
            theme_minimal() +
            theme(legend.position = "bottom",
                  plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                  plot.caption.position = "plot",
                  legend.key.height = unit(0.5, "lines"),
                  legend.key.width = unit(1, "lines"),
                  panel.grid = element_blank(),
                  axis.line = element_line(color = "black"))
        
        # 存储高度信息
        attr(p, "plot_height") <- plot_height
        
        return(list(table = result_table, plot = p))
    }, error = function(e) {
        warning(paste("第", i, "行：stack_bar_subdim函数执行失败：", e$message))
        NULL
    })
}

# 9.6. stack_bar_choices_based函数
generate_stack_bar_choices_based <- function(dat, index_report_row, index_item, i, color_palette,
                                             is_three_level_compare = FALSE, dat_qd = NULL, dat_dist = NULL, school_name = NULL) {
    tryCatch({
        # 获取报告维度
        dim <- index_report_row$报告维度
        if (is.na(dim) || dim == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 根据数据表对应过滤index_item
        index_item_filtered <- filter_index_item_by_data_table(index_item, index_report_row)
        
        # 在index_item中找到该维度的所有题目列名
        items <- index_item_filtered %>%
            filter(报告维度 == dim) %>%
            pull(题目列名) %>%
            unique()
        
        if (length(items) == 0) {
            warning(paste("第", i, "行：维度", dim, "未找到题目"))
            return(NULL)
        }
        
        # 检查哪些题目列存在
        existing_items <- items[items %in% colnames(dat)]
        if (length(existing_items) == 0) {
            warning(paste("第", i, "行：未找到任何题目列"))
            return(NULL)
        }
        
        # 获取第一个题目的选项（所有题目的选项应该相同）
        first_item_row <- index_item_filtered %>%
            filter(题目列名 == existing_items[1]) %>%
            slice(1)
        
        if (nrow(first_item_row) == 0 || is.na(first_item_row$选项) || first_item_row$选项 == "") {
            warning(paste("第", i, "行：题目", existing_items[1], "的选项为空"))
            return(NULL)
        }
        
        # 解析选项
        options_str <- first_item_row$选项
        options <- strsplit(options_str, "//C//", fixed = TRUE)[[1]]
        options <- trimws(options)
        
        # 计算交叉表
        # Y轴显示总体和各区市，stack显示选项（fill）
        result_table <- data.frame(
            Y类别 = character(),
            stack类别 = character(),
            占比 = numeric(),
            stringsAsFactors = FALSE
        )
        
        # 三级对比逻辑
        if (is_three_level_compare) {
            # 检查必要的数据是否提供
            if (is.null(dat_qd) || is.null(dat_dist) || is.null(school_name)) {
                warning(paste("第", i, "行：三级对比模式需要提供dat_qd、dat_dist和school_name参数"))
                return(NULL)
            }
            
            # 获取学校所在区市（从dat_dist中获取，因为dat_dist已经过滤了该区市的数据）
            if ("区市" %in% colnames(dat_dist) && nrow(dat_dist) > 0) {
                school_district <- as.character(unique(dat_dist$区市)[1])
            } else {
                warning(paste("第", i, "行：无法从dat_dist中确定学校所在的区市"))
                return(NULL)
            }
            
            # 三级对比：Y类别固定为"青岛市"、"区市"、"本校"
            Y_categories <- c("青岛市", school_district, "本校")
            
            # 对于每个Y类别，计算选项的占比均数
            for (y_cat in Y_categories) {
                if (y_cat == "青岛市") {
                    dat_subset <- dat_qd
                } else if (y_cat == school_district) {
                    dat_subset <- dat_dist
                } else if (y_cat == "本校") {
                    dat_subset <- dat
                } else {
                    next
                }
                
                # 计算该Y类别的占比均数
                pct_values <- numeric(length(options))
                for (opt_idx in seq_along(options)) {
                    opt_value <- opt_idx  # 选项值对应1, 2, 3, ...
                    pct_sum <- 0
                    item_count <- 0
                    
                    for (item in existing_items) {
                        if (!item %in% colnames(dat_subset)) {
                            next
                        }
                        n_total <- sum(!is.na(dat_subset[[item]]))
                        if (n_total > 0) {
                            n_count <- sum(dat_subset[[item]] == opt_value, na.rm = TRUE)
                            pct <- (n_count / n_total) * 100
                            pct_sum <- pct_sum + pct
                            item_count <- item_count + 1
                        }
                    }
                    
                    if (item_count > 0) {
                        pct_values[opt_idx] <- pct_sum / item_count
                    }
                }
                
                # 归一化确保总和为100%
                if (sum(pct_values) > 0) {
                    pct_values <- pct_values / sum(pct_values) * 100
                }
                
                # 四舍五入后，调整最后一个类别使总和为100%
                pct_rounded <- round(pct_values, 1)
                if (abs(sum(pct_rounded) - 100) > 0.01) {
                    diff <- 100 - sum(pct_rounded[-length(pct_rounded)])
                    pct_rounded[length(pct_rounded)] <- diff
                }
                
                # 添加到结果表
                for (j in seq_along(options)) {
                    result_table <- rbind(result_table, data.frame(
                        Y类别 = y_cat,
                        stack类别 = options[j],
                        占比 = pct_rounded[j]
                    ))
                }
            }
        } else {
            # 原有逻辑
            # 计算总体（青岛市）的占比均数
            # 对于每个选项，计算在所有题目上的占比均数
            pct_values_overall <- numeric(length(options))
            for (opt_idx in seq_along(options)) {
                opt_value <- opt_idx  # 选项值对应1, 2, 3, ...
                pct_sum <- 0
                item_count <- 0
                
                for (item in existing_items) {
                    if (!item %in% colnames(dat)) {
                        next
                    }
                    n_total <- sum(!is.na(dat[[item]]))
                    if (n_total > 0) {
                        n_count <- sum(dat[[item]] == opt_value, na.rm = TRUE)
                        pct <- (n_count / n_total) * 100
                        pct_sum <- pct_sum + pct
                        item_count <- item_count + 1
                    }
                }
                
                if (item_count > 0) {
                    pct_values_overall[opt_idx] <- pct_sum / item_count
                }
            }
            
            # 归一化确保总和为100%
            if (sum(pct_values_overall) > 0) {
                pct_values_overall <- pct_values_overall / sum(pct_values_overall) * 100
            }
            
            # 四舍五入后，调整最后一个类别使总和为100%
            pct_rounded_overall <- round(pct_values_overall, 1)
            if (abs(sum(pct_rounded_overall) - 100) > 0.01) {
                diff <- 100 - sum(pct_rounded_overall[-length(pct_rounded_overall)])
                pct_rounded_overall[length(pct_rounded_overall)] <- diff
            }
            
            # 添加到结果表（总体）
            for (j in seq_along(options)) {
                result_table <- rbind(result_table, data.frame(
                    Y类别 = "青岛市",
                    stack类别 = options[j],
                    占比 = pct_rounded_overall[j]
                ))
            }
            
            # 计算每个区市的占比均数
            if ("区市" %in% colnames(dat)) {
                # dat$区市已经是factor，直接使用levels
                qu_shi_levels <- levels(dat$区市)
                qu_shi_levels <- qu_shi_levels[qu_shi_levels %in% unique(dat$区市)]
                
                for (qu_shi in qu_shi_levels) {
                    # 筛选条件：区市匹配且existing_items列都不为空
                    filter_condition <- dat$区市 == qu_shi & !is.na(dat$区市)
                    
                    # 确保existing_items列都不为空
                    for (item in existing_items) {
                        if (item %in% colnames(dat)) {
                            filter_condition <- filter_condition & !is.na(dat[[item]])
                        }
                    }
                    
                    dat_subset <- dat[filter_condition, existing_items] 
                    
                    if (nrow(dat_subset) == 0) {
                        next
                    }
                    
                    pct_values <- numeric(length(options))
                    for (opt_idx in seq_along(options)) {
                        opt_value <- opt_idx
                        pct_sum <- 0
                        item_count <- 0
                        
                        for (item in existing_items) {
                            if (!item %in% colnames(dat_subset)) {
                                next
                            }
                            n_total <- sum(!is.na(dat_subset[[item]]))
                            if (n_total > 0) {
                                n_count <- sum(dat_subset[[item]] == opt_value, na.rm = TRUE)
                                pct <- (n_count / n_total) * 100
                                pct_sum <- pct_sum + pct
                                item_count <- item_count + 1
                            }
                        }
                        
                        if (item_count > 0) {
                            pct_values[opt_idx] <- pct_sum / item_count
                        }
                    }
                    
                    # 归一化确保总和为100%
                    if (sum(pct_values) > 0) {
                        pct_values <- pct_values / sum(pct_values) * 100
                    }
                    
                    # 四舍五入后，调整最后一个类别使总和为100%
                    pct_rounded <- round(pct_values, 1)
                    if (abs(sum(pct_rounded) - 100) > 0.01) {
                        diff <- 100 - sum(pct_rounded[-length(pct_rounded)])
                        pct_rounded[length(pct_rounded)] <- diff
                    }
                    
                    # 添加到结果表
                    for (j in seq_along(options)) {
                        result_table <- rbind(result_table, data.frame(
                            Y类别 = qu_shi,
                            stack类别 = options[j],
                            占比 = pct_rounded[j]
                        ))
                    }
                }
            }
        }
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_9.6_stack_bar_choices_based.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 确保Y类别按照正确的顺序（用于Y轴）
        if (is_three_level_compare) {
            # 三级对比：Y类别固定为"青岛市"、"区市"、"本校"
            Y_levels <- Y_categories
            Y_levels <- rev(Y_levels)  # 反转顺序，使"青岛市"显示在最上面
        } else {
            # Y类别是总体和各区市
            if ("区市" %in% colnames(dat)) {
                Y_levels <- c("青岛市", levels(dat$区市))
                # 只保留实际存在的类别
                Y_levels <- Y_levels[Y_levels %in% unique(result_table$Y类别)]
                # 反转顺序，使"青岛市"显示在最上面
                Y_levels <- rev(Y_levels)
            } else {
                Y_levels <- unique(result_table$Y类别)
                Y_levels <- rev(Y_levels)
            }
        }
        result_table$Y类别 <- factor(result_table$Y类别, levels = Y_levels)
        
        # 绘制累积条形图
        n_y_categories <- length(unique(result_table$Y类别))
        if (n_y_categories <= 3) {
            plot_height <- 3
        } else {
            plot_height <- 3 + (n_y_categories - 3) * 0.4
        }
        
        # 确保stack类别按照正确的顺序（用于图例）
        result_table$stack类别 <- factor(result_table$stack类别, levels = options)
        
        # 使用颜色映射函数
        color_mapping_stack <- get_color_mapping(options, color_palette)
        
        # 计算每个标签的位置（用于处理重叠）
        reversed_options <- rev(options)
        
        # 对于每个Y类别，计算stack的累积位置
        result_table$cumsum_start <- 0
        result_table$cumsum_end <- 0
        result_table$label_x <- 0
        result_table$need_line <- FALSE
        result_table$line_x_start <- 0
        result_table$line_x_end <- 0
        
        for (y_cat in Y_levels) {
            y_data <- result_table[result_table$Y类别 == y_cat, ]
            y_data <- y_data[order(match(y_data$stack类别, reversed_options)), ]
            
            cumsum_val <- 0
            for (k in seq_len(nrow(y_data))) {
                y_data$cumsum_start[k] <- cumsum_val
                cumsum_val <- cumsum_val + y_data$占比[k]
                y_data$cumsum_end[k] <- cumsum_val
                y_data$label_x[k] <- (y_data$cumsum_start[k] + y_data$cumsum_end[k]) / 2
                
                # 判断是否需要拉线（占比<5）
                if (y_data$占比[k] < 5) {
                    y_data$need_line[k] <- TRUE
                    y_data$line_x_start[k] <- y_data$label_x[k]
                    y_data$line_x_end[k] <- y_data$label_x[k] + 3
                }
            }
            
            # 处理相邻多个小标签的情况，错开x位置
            if (sum(y_data$need_line) > 1) {
                small_labels <- which(y_data$need_line)
                for (idx in seq_along(small_labels)) {
                    k <- small_labels[idx]
                    offset <- 1 + (idx - 1) * 4
                    y_data$line_x_end[k] <- y_data$label_x[k] + offset
                }
            }
            
            # 更新result_table
            result_table[result_table$Y类别 == y_cat, ] <- y_data
        }
        
        # Y轴显示Y类别（子维度），X轴显示占比（0-100%），stack类别作为fill
        p <- ggplot(result_table, aes(x = 占比, y = Y类别, fill = stack类别)) +
            geom_bar(stat = "identity", position = "stack", width = 0.4) +
            scale_fill_manual(values = color_mapping_stack, name = "", breaks = options)
        
        # 添加拉线（仅对占比<5的标签）
        line_data <- result_table[result_table$need_line, ]
        
        # 检查是否为三级对比模式（通过检查Y类别是否包含"本校"、"青岛市"等）
        is_three_level_compare_subdim <- "本校" %in% result_table$Y类别 && "青岛市" %in% result_table$Y类别
        
        # 三级对比模式：只保留"本校"的拉线
        if (is_three_level_compare_subdim || is_three_level_compare) {
            line_data <- line_data[line_data$Y类别 == "本校", ]
        }
        
        if (nrow(line_data) > 0) {
            line_data$y_start <- as.numeric(line_data$Y类别)
            line_data$y_end <- as.numeric(line_data$Y类别) + 0.3
            
            p <- p + geom_segment(data = line_data,
                                 aes(x = line_x_start, xend = line_x_end, 
                                     y = y_start, yend = y_end),
                                 inherit.aes = FALSE,
                                 color = "black",
                                 linewidth = 0.3)
        }
        
        # 添加标签
        result_table$Lable <- ""
        result_table$Lable[!result_table$need_line] <- paste0(round(result_table$占比[!result_table$need_line], 1), "%")
        
        # 三级对比模式：只显示"本校"的标签
        if (is_three_level_compare_subdim || is_three_level_compare) {
            result_table$Lable[!result_table$need_line & result_table$Y类别 != "本校"] <- ""
            # 同时处理需要拉线的标签
            result_table$Lable[result_table$need_line & result_table$Y类别 != "本校"] <- ""
        }
        
        if (nrow(result_table[!result_table$need_line, ]) > 0) {
            p <- p + geom_text(data = result_table,
                             aes(x = 占比, y = Y类别, label = Lable),
                             inherit.aes = FALSE,
                             position = position_stack(vjust = 0.5),
                             size = 3)
        }
        
        # 需要拉线的标签
        if (nrow(line_data) > 0) {
            # 为拉线标签准备label列
            line_data$label_text <- paste0(round(line_data$占比, 1), "%")
            # 三级对比模式：只显示"本校"的标签（此时line_data已经过滤，只包含"本校"的数据）
            if (is_three_level_compare_subdim || is_three_level_compare) {
                line_data$label_text[line_data$Y类别 != "本校"] <- ""
            }
            p <- p + geom_text(data = line_data,
                             aes(x = line_x_end, y = y_end, label = label_text),
                             inherit.aes = FALSE,
                             hjust = 0.5,
                             vjust = -0.1,
                             size = 2.7)
        }
        
        # 计算图例需要的行数
        n_legend_items <- length(options)
        n_string_length <- sum(nchar(options))
        
        legend_nrow <- if (n_legend_items <= 3) {
            1
        } else if (n_legend_items <= 6 & n_string_length <= 50) {
            2
        } else {
            3
        }
        
        p <- p +
            labs(caption = ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题),
                 x = "", y = "") +
            scale_x_continuous(labels = function(x) paste0(x, "%"), limits = c(0, 109), breaks = seq(0, 100, by = 10), expand = c(0, 0)) +
            guides(fill = guide_legend(nrow = legend_nrow, byrow = TRUE)) +
            theme_minimal() +
            theme(legend.position = "bottom",
                  plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                  plot.caption.position = "plot",
                  legend.key.height = unit(0.5, "lines"),
                  legend.key.width = unit(1, "lines"),
                  panel.grid = element_blank(),
                  axis.line = element_line(color = "black"))
        
        # 存储高度信息
        attr(p, "plot_height") <- plot_height
        
        return(list(table = result_table, plot = p))
    }, error = function(e) {
        warning(paste("第", i, "行：stack_bar_choices_based函数执行失败：", e$message))
        NULL
    })
}

# 9.7. choices_pct函数（多维选择题：仅总体占比表 + 说明文字，无三级对比、不绘图）
generate_choices_pct <- function(dat, index_report_row, index_item, i, color_palette) {
    tryCatch({
        dim <- index_report_row$报告维度
        if (is.na(dim) || dim == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        index_item_filtered <- filter_index_item_by_data_table(index_item, index_report_row)
        
        items <- index_item_filtered %>%
            filter(报告维度 == dim) %>%
            pull(题目列名) %>%
            unique()
        
        if (length(items) == 0) {
            warning(paste("第", i, "行：维度", dim, "未找到题目"))
            return(NULL)
        }
        
        existing_items <- items[items %in% colnames(dat)]
        if (length(existing_items) == 0) {
            warning(paste("第", i, "行：未找到任何题目列"))
            return(NULL)
        }
        
        first_item_row <- index_item_filtered %>%
            filter(题目列名 == existing_items[1]) %>%
            slice(1)
        
        if (nrow(first_item_row) == 0 || is.na(first_item_row$选项) || first_item_row$选项 == "") {
            warning(paste("第", i, "行：题目", existing_items[1], "的选项为空"))
            return(NULL)
        }
        
        options_str <- first_item_row$选项
        options <- strsplit(options_str, "//C//", fixed = TRUE)[[1]]
        options <- trimws(options)
        
        pct_values_overall <- numeric(length(options))
        for (opt_idx in seq_along(options)) {
            opt_value <- opt_idx
            pct_sum <- 0
            item_count <- 0
            
            for (item in existing_items) {
                if (!item %in% colnames(dat)) {
                    next
                }
                n_total <- sum(!is.na(dat[[item]]))
                if (n_total > 0) {
                    n_count <- sum(dat[[item]] == opt_value, na.rm = TRUE)
                    pct <- (n_count / n_total) * 100
                    pct_sum <- pct_sum + pct
                    item_count <- item_count + 1
                }
            }
            
            if (item_count > 0) {
                pct_values_overall[opt_idx] <- pct_sum / item_count
            }
        }
        
        if (sum(pct_values_overall) > 0) {
            pct_values_overall <- pct_values_overall / sum(pct_values_overall) * 100
        }
        
        pct_rounded <- round(pct_values_overall, 1)
        if (abs(sum(pct_rounded) - 100) > 0.01) {
            diff <- 100 - sum(pct_rounded[-length(pct_rounded)])
            pct_rounded[length(pct_rounded)] <- diff
        }
        pct_rounded <- round(pct_rounded, 1)
        
        fmt_pct <- function(x) paste0(sprintf("%.1f", as.numeric(x)), "%")
        
        dim_name <- ifelse(is.na(dim) || dim == "", "该维度", dim)
        
        result_table <- data.frame(范围 = "本校", stringsAsFactors = FALSE)
        for (j in seq_along(options)) {
            coln <- options[j]
            if (is.na(coln) || coln == "") {
                coln <- paste0("选项", j)
            }
            result_table[[coln]] <- fmt_pct(pct_rounded[j])
        }
        names(result_table) <- make.unique(names(result_table), sep = " ")
        
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_choices_pct.csv"),
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        role_lab <- "家长"
        if (!is.na(index_report_row$数据表对应)) {
            dt <- as.character(index_report_row$数据表对应)
            if (dt %in% c("stu")) {
                role_lab <- "学生"
            } else if (dt %in% c("tea")) {
                role_lab <- "教师"
            } else if (dt %in% c("par", "stu_par")) {
                role_lab <- "家长"
            }
        }
        
        # 动态文字：仅保留占比大于 0 的选项后再排序、组句（表格仍含全部选项）
        keep_txt <- pct_rounded > 0 & !is.na(pct_rounded)
        options_txt <- options[keep_txt]
        pcts_txt <- pct_rounded[keep_txt]
        ord <- order(pcts_txt, decreasing = TRUE, seq_along(options_txt))
        opts_ord <- options_txt[ord]
        pcts_ord <- pcts_txt[ord]
        n_opt <- length(opts_ord)
        
        if (n_opt == 0) {
            text_out <- ""
        } else if (n_opt == 1) {
            text_out <- paste0("在", dim_name, "方面，", fmt_pct(pcts_ord[1]), "的", role_lab, "表示", opts_ord[1], "。")
        } else {
            p_top2 <- round(sum(pcts_ord[1:2]), 1)
            chunks <- paste0(fmt_pct(p_top2), "的", role_lab, "表示", opts_ord[1], "或", opts_ord[2])
            if (n_opt >= 3) {
                for (k in 3:n_opt) {
                    chunks <- c(chunks, paste0(fmt_pct(pcts_ord[k]), "的", role_lab, "表示", opts_ord[k]))
                }
            }
            text_out <- paste0("在", dim_name, "方面，", paste(chunks, collapse = "，"), "。")
        }
        
        return(list(table = result_table, text = text_out))
    }, error = function(e) {
        warning(paste("第", i, "行：choices_pct函数执行失败：", e$message))
        NULL
    })
}

# 10. difference_class函数
generate_difference_class <- function(dat, index_report_row, index_item, i, color_palette) {
    tryCatch({
        dim_or_item <- index_report_row$dim_or_item
        if (is.na(dim_or_item) || dim_or_item == "") {
            warning(paste("第", i, "行：dim_or_item为空"))
            return(NULL)
        }
        
        # 获取报告维度
        dim_or_item_value <- index_report_row$报告维度
        if (is.na(dim_or_item_value) || dim_or_item_value == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 确定X变量（分类变量）
        if (dim_or_item == "dim") {
            X_col <- paste0(dim_or_item_value, "_Class")
        } else {
            # 对于item类型，使用模糊匹配查找列名（处理括号问题）
            all_cols <- colnames(dat)
            # 先尝试精确匹配
            if (dim_or_item_value %in% all_cols) {
                X_col <- dim_or_item_value
            } else {
                # 使用模糊匹配（fixed = TRUE 避免正则表达式问题）
                matching_cols <- all_cols[grepl(dim_or_item_value, all_cols, fixed = TRUE)]
                if (length(matching_cols) > 0) {
                    # 选择最匹配的（完全匹配或最短的）
                    exact_match <- matching_cols[matching_cols == dim_or_item_value]
                    if (length(exact_match) > 0) {
                        X_col <- exact_match[1]
                    } else {
                        X_col <- matching_cols[1]
                    }
                } else {
                    warning(paste("第", i, "行：未找到X变量", dim_or_item_value))
                    return(NULL)
                }
            }
        }
        
        if (!X_col %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到X变量", X_col))
            return(NULL)
        }
        
        # 根据数据表对应过滤index_item
        index_item_filtered <- filter_index_item_by_data_table(index_item, index_report_row)
        
        # 获取X变量的类别（按index_item中的顺序）
        if (dim_or_item == "dim") {
            item_row <- index_item_filtered %>% filter(报告维度 == dim_or_item_value) %>% slice(1)
            if (nrow(item_row) == 0) {
                warning(paste("第", i, "行：未找到维度", dim_or_item_value, "的信息"))
                return(NULL)
            }
            X_categories <- c()
            for (j in 1:10) {
                col_name <- paste0("报告维度分类名", j)
                if (col_name %in% colnames(index_item_filtered)) {
                    cat_val <- item_row[[col_name]]
                    if (!is.na(cat_val) && cat_val != "") {
                        X_categories <- c(X_categories, as.character(cat_val))
                    }
                }
            }
            # 只保留dat中实际存在的类别，但保持index_item中的顺序
            X_categories <- X_categories[X_categories %in% unique(dat[[X_col]])]
        } else if (dim_or_item == "basic") {
            X_categories <- levels(dat[[X_col]])
        } else {
            # 对于item类型，使用模糊匹配查找index_item中的题目（处理括号问题）
            # 先尝试精确匹配
            item_row <- index_item_filtered %>% filter(题目列名 == dim_or_item_value) %>% slice(1)
            if (nrow(item_row) == 0) {
                # 使用模糊匹配
                item_row <- index_item_filtered %>%
                    filter(str_detect(题目列名, fixed(dim_or_item_value))) %>%
                    slice(1)
            }
            if (nrow(item_row) == 0) {
                warning(paste("第", i, "行：未找到题目", dim_or_item_value, "的信息"))
                return(NULL)
            }
            options_str <- item_row$选项
            if (is.na(options_str) || options_str == "") {
                warning(paste("第", i, "行：题目", dim_or_item_value, "的选项为空"))
                return(NULL)
            }
            X_categories <- strsplit(options_str, "//C//", fixed = TRUE)[[1]]
            X_categories <- trimws(X_categories)
            # 只保留dat中实际存在的类别，但保持index_item中的顺序
            X_categories <- X_categories[X_categories %in% unique(dat[[X_col]])]
        }
        
        # 获取Y变量（连续变量）
        chart_type <- index_report_row$图表类型
        Y_vars_str <- index_report_row$交叉或分类变量
        if (is.na(Y_vars_str) || Y_vars_str == "") {
            warning(paste("第", i, "行：交叉或分类变量为空"))
            return(NULL)
        }
        
        Y_vars <- strsplit(Y_vars_str, "、", fixed = TRUE)[[1]]
        Y_vars <- trimws(Y_vars)
        
        # 确定Y变量的后缀
        if (grepl("总分|量尺分|标准分", Y_vars_str)) {
            Y_suffix <- ""
        } else {
            # 从图表类型中提取后缀
            if (grepl("difference_class_", chart_type)) {
                suffix_match <- regmatches(chart_type, regexpr("difference_class_(.+)", chart_type))
                if (length(suffix_match) > 0) {
                    # 提取后缀，保留下划线（例如 "difference_class_Score" -> "_Score"）
                    Y_suffix <- paste0("_", sub("difference_class_", "", suffix_match[1]))
                } else {
                    Y_suffix <- "_Figure"
                }
            } else {
                Y_suffix <- "_Figure"
            }
        }
        
        # 构建Y变量列名
        Y_cols <- c()
        for (y_var in Y_vars) {
            if (y_var == "总分") {
                Y_cols <- c(Y_cols, "总分")
            } else {
                Y_cols <- c(Y_cols, paste0(y_var, Y_suffix))
            }
        }
        
        # 检查哪些Y变量存在
        existing_Y_cols <- Y_cols[Y_cols %in% colnames(dat)]
        if (length(existing_Y_cols) == 0) {
            warning(paste("第", i, "行：未找到任何Y变量"))
            return(NULL)
        }
        
        # 计算交叉表
        result_table <- data.frame(
            X类别 = character(),
            Y名称 = character(),
            人数 = numeric(),
            均分 = numeric(),
            stringsAsFactors = FALSE
        )
        
        # 获取所有Y变量的名称
        Y_names <- c()
        for (Y_col in existing_Y_cols) {
            Y_name <- gsub(paste0(Y_suffix, "$"), "", Y_col)
            if (Y_name == Y_col) {
                Y_name <- Y_col
            }
            Y_names <- c(Y_names, Y_name)
        }
        
        # 计算所有Y变量和X类别的交叉表
        for (Y_col in existing_Y_cols) {
            Y_name <- gsub(paste0(Y_suffix, "$"), "", Y_col)
            if (Y_name == Y_col) {
                Y_name <- Y_col
            }
            
            for (x_cat in X_categories) {
                dat_subset <- dat[dat[[X_col]] == x_cat & !is.na(dat[[X_col]]), ]
                n_valid <- sum(!is.na(dat_subset[[Y_col]]))
                if (n_valid > 0) {
                    mean_val <- mean(dat_subset[[Y_col]], na.rm = TRUE)
                } else {
                    mean_val <- 0  # N=0时，均分设为0，确保类别仍然显示
                }
                
                result_table <- rbind(result_table, data.frame(
                    X类别 = x_cat,
                    Y名称 = Y_name,
                    人数 = n_valid,
                    均分 = round(mean_val, 3)
                ))
            }
        }
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_10_difference_class.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 判断是单个还是多个Y变量
        if (length(existing_Y_cols) == 1) {
            # 单个Y变量：保持原有逻辑（单个条形图 + 差异检验）
            Y_col <- existing_Y_cols[1]
            Y_name <- Y_names[1]
            
            plot_data <- result_table %>% filter(Y名称 == Y_name)
            # 确保X类别按照X_categories的顺序
            plot_data$X类别 <- factor(plot_data$X类别, levels = X_categories)
            plot_data <- plot_data[order(plot_data$X类别), ]
            
            # 创建X轴标签（类别名称 + \n + N=人数）
            # 对X类别名称进行分段处理：超过10个字符的要分段
            x_category_labels <- sapply(plot_data$X类别, function(x) {
                x_str <- as.character(x)
                
                # 第一步：检查是否存在"（"或"("字符，如果有，在这些字符前插入换行符分段
                if (grepl("（|\\(", x_str)) {
                    # 找到"（"或"("的位置
                    pos1 <- regexpr("（", x_str)[1]
                    pos2 <- regexpr("\\(", x_str)[1]
                    
                    # 选择第一个出现的位置
                    if (pos1 > 0 && pos2 > 0) {
                        split_pos <- min(pos1, pos2)
                    } else if (pos1 > 0) {
                        split_pos <- pos1
                    } else {
                        split_pos <- pos2
                    }
                    
                    # 分段
                    part1 <- substr(x_str, 1, split_pos - 1)
                    part2 <- substr(x_str, split_pos, nchar(x_str))
                    segments <- c(part1, part2)
                } else {
                    segments <- x_str
                }
                
                # 第二步：对每一段，如果字符数>8，平均分成2段
                result_segments <- character()
                for (seg in segments) {
                    seg_len <- nchar(seg)
                    if (seg_len > 8) {
                        # 平均分成2段
                        mid_pos <- ceiling(seg_len / 2)
                        seg1 <- substr(seg, 1, mid_pos)
                        seg2 <- substr(seg, mid_pos + 1, seg_len)
                        result_segments <- c(result_segments, seg1, seg2)
                    } else {
                        result_segments <- c(result_segments, seg)
                    }
                }
                
                # 用换行符连接所有段
                paste(result_segments, collapse = "\n")
            })
            x_labels <- paste0(x_category_labels, "\nN=", plot_data$人数)
            names(x_labels) <- plot_data$X类别
            
            # 使用颜色映射函数（特殊处理"达标"和"不达标"）
            # difference_class 使用反向颜色顺序
            color_mapping_x <- get_color_mapping(X_categories, color_palette, reverse = TRUE)
            
            # 判断是否为_Figure类型，需要特殊处理
            is_figure_type <- (Y_suffix == "_Figure")
            
            # 差异检验（_Figure类型不进行差异检验）
            sig_label <- ""
            if (!is_figure_type) {
                # 定义类别数量（用于差异检验）
                n_categories <- length(X_categories)
                
                
                # 差异检验
                test_result <- tryCatch({
                    if (n_categories == 2) {
                        # t检验
                        group1 <- dat[dat[[X_col]] == X_categories[1] & !is.na(dat[[X_col]]), Y_col]
                        group2 <- dat[dat[[X_col]] == X_categories[2] & !is.na(dat[[X_col]]), Y_col]
                        group1 <- group1[!is.na(group1)]
                        group2 <- group2[!is.na(group2)]
                        if (length(group1) > 0 && length(group2) > 0) {
                            t_test <- t.test(group1, group2)
                            list(type = "t", p_value = t_test$p.value, 
                                 max_diff = abs(mean(group1, na.rm = TRUE) - mean(group2, na.rm = TRUE)))
                        } else {
                            NULL
                        }
                    } else {
                        # ANOVA
                        aov_data <- dat[!is.na(dat[[X_col]]) & !is.na(dat[[Y_col]]), ]
                        if (nrow(aov_data) > 0) {
                            aov_result <- aov(as.formula(paste(Y_col, "~", X_col)), data = aov_data)
                            aov_summary <- summary(aov_result)
                            p_value <- aov_summary[[1]][["Pr(>F)"]][1]
                            means <- aggregate(aov_data[[Y_col]], by = list(aov_data[[X_col]]), FUN = mean, na.rm = TRUE)
                            max_diff <- max(means$x) - min(means$x)
                            list(type = "F", p_value = p_value, max_diff = max_diff)
                        } else {
                            NULL
                        }
                    }
                }, error = function(e) {
                    return(NULL)
                })
                
                # 构建显著性标记
                if (!is.null(test_result)) {
                    if (test_result$p_value < 0.001) {
                        sig_label <- paste0("各等级间相差的最大差值：", round(test_result$max_diff, 1), "***")
                    } else if (test_result$p_value < 0.01) {
                        sig_label <- paste0("各等级间相差的最大差值：", round(test_result$max_diff, 1), "**")
                    } else if (test_result$p_value < 0.05) {
                        sig_label <- paste0("各等级间相差的最大差值：", round(test_result$max_diff, 1), "*")
                    }
                }
            }
            
            plot_title <- ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题)
            
            # 计算Y轴上限（动态调整，根据数据大小灵活设置）
            if (is_figure_type) {
                # _Figure类型：Y轴固定为0-100
                y_upper_limit <- 109
                y_breaks <- seq(0, 100, by = 10)
                # 准备label：均分*100并加上%符号
                plot_data$均分 <- plot_data$均分 * 100
                plot_data$label_text <- ifelse(plot_data$人数 > 0, 
                                               paste0(round(plot_data$均分, 1), "%"), 
                                               "")
            } else {
            y_max <- max(plot_data$均分, na.rm = TRUE)
            
            if (y_max <= 0) {
                y_upper_limit <- 10  # 如果最大值<=0，设置默认上限
            } else if (y_max < 10) {
                # 个位数：增加20%或至少2个单位，向上取整到最近的整数
                y_upper_limit <- ceiling(max(y_max * 1.2, y_max + 2))
            } else if (y_max < 50) {
                # 10-50：增加15%或至少5个单位，向上取整到最近的5的倍数
                y_upper_limit <- ceiling(max(y_max * 1.15, y_max + 5) / 5) * 5
            } else if (y_max < 100) {
                # 50-100：增加12%或至少10个单位，向上取整到最近的10的倍数
                y_upper_limit <- ceiling(max(y_max * 1.12, y_max + 10) / 10) * 10
            } else if (y_max < 400) {
                # 100-400：增加10%或至少20个单位，向上取整到最近的20的倍数
                y_upper_limit <- ceiling(max(y_max * 1.1, y_max + 20) / 20) * 20
            } else {
                # 400以上：增加15%的空间，向上取整到最近的50的倍数
                y_upper_limit <- ceiling(y_max * 1.15 / 50) * 50
            }
            y_breaks <- NULL  # 使用默认breaks
            # 准备label：根据Y_name是否在figures_with_dot中决定格式
            if (Y_name %in% figures_with_dot) {
                # 添加%符号，保留1位小数
                plot_data$label_text <- ifelse(plot_data$人数 > 0, 
                                               paste0(round(plot_data$均分, 1), "%"), 
                                               "")
            } else {
                # 不添加%符号，保留整数
                plot_data$label_text <- ifelse(plot_data$人数 > 0, 
                                               round(plot_data$均分, 0), 
                                               "")
            }
            }
            
            final_plot <- ggplot(plot_data, aes(x = X类别, y = 均分, fill = X类别)) +
                geom_bar(stat = "identity", width = 0.4) +
                scale_fill_manual(values = color_mapping_x) +
                scale_x_discrete(labels = x_labels) +  # 设置X轴标签（包含N=人数）
                # 均分标注（N>0时显示）
                geom_text(aes(label = label_text), vjust = -0.5, size = 3) +
                labs(caption = plot_title,
                     subtitle = ifelse(sig_label != "", sig_label, ""),
                     x = "", y = "") +
                scale_y_continuous(limits = c(0, y_upper_limit), 
                                  breaks = if(is_figure_type) y_breaks else waiver(),
                                  labels = if(is_figure_type) {
                                      function(x) paste0(x, "%")
                                  } else if(Y_name %in% figures_with_dot) {
                                      function(x) paste0(x, "%")
                                  } else {
                                      waiver()
                                  },
                                  expand = c(0, 0)) +
                theme_minimal() +
                theme(legend.position = "none",
                      plot.caption = element_text(hjust = 0.5, size = 11, family = "STKaiti"),
                      plot.caption.position = "plot",  # 相对于整个绘图区域居中
                      plot.subtitle = element_text(hjust = 0, size = 9, family = "STKaiti"),
                      axis.text.x = element_text(angle = 0, vjust = 1, margin = margin(t = 12), family = "PingFang SC"),
                      panel.grid = element_blank(),  # 去掉所有背景网格线
                      axis.line = element_line(color = "black"))  # 添加X轴和Y轴线
            
        } else {
            # 多个Y变量：做分组条形图，不进行差异检验
            plot_data <- result_table
            # 确保X类别按照X_categories的顺序
            plot_data$X类别 <- factor(plot_data$X类别, levels = X_categories)
            # 确保Y名称按照Y_names的顺序
            plot_data$Y名称 <- factor(plot_data$Y名称, levels = Y_names)
            plot_data <- plot_data[order(plot_data$X类别, plot_data$Y名称), ]
            
            # 使用颜色映射函数为Y变量分配颜色
            color_mapping_y <- get_color_mapping(Y_names, color_palette, reverse = FALSE)
            
            plot_title <- ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题)
            
            # 判断是否为_Figure类型，需要特殊处理
            is_figure_type <- (Y_suffix == "_Figure")
            
            # 检查是否有Y变量在figures_with_dot中（用于决定Y轴标签格式）
            has_figures_with_dot <- any(Y_names %in% figures_with_dot)
            
            # 计算Y轴上限（动态调整，根据数据大小灵活设置）
            if (is_figure_type) {
                # _Figure类型：Y轴固定为0-100
                # 准备label：figures_with_dot的有百分号、一位小数；否则没有%，整数
                if (has_figures_with_dot) {
                    plot_data$label_text <- ifelse(plot_data$人数 > 0, 
                                               paste0(round(plot_data$均分 * 100, 1), "%"), 
                                               "")
                    y_upper_limit <- 40
                    y_breaks <- seq(0, 40, by = 5)

                } else {
                    plot_data$label_text <- ifelse(plot_data$人数 > 0, 
                                               round(plot_data$均分 * 100, 0), 
                                               "")
                    y_upper_limit <- 109
                    y_breaks <- seq(0, 100, by = 10)
                }
                plot_data$均分 <- plot_data$均分 * 100
            } else {
            y_max <- max(plot_data$均分, na.rm = TRUE)
            
            if (y_max <= 0) {
                y_upper_limit <- 10  # 如果最大值<=0，设置默认上限
            } else if (y_max < 10) {
                # 个位数：增加20%或至少2个单位，向上取整到最近的整数
                y_upper_limit <- ceiling(max(y_max * 1.08, y_max + 1))
            } else if (y_max < 50) {
                # 10-50：增加15%或至少5个单位，向上取整到最近的5的倍数
                y_upper_limit <- ceiling(max(y_max * 1.15, y_max + 5) / 5) * 5
            } else if (y_max < 100) {
                # 50-100：增加12%或至少10个单位，向上取整到最近的10的倍数
                y_upper_limit <- ceiling(max(y_max * 1.12, y_max + 10) / 10) * 10
            } else if (y_max < 400) {
                # 100-400：增加10%或至少20个单位，向上取整到最近的20的倍数
                y_upper_limit <- ceiling(max(y_max * 1.1, y_max + 20) / 20) * 20
            } else {
                # 400以上：增加15%的空间，向上取整到最近的50的倍数
                y_upper_limit <- ceiling(y_max * 1.15 / 50) * 50
                }
                y_breaks <- NULL  # 使用默认breaks
                # 准备label：普通格式
                plot_data$label_text <- ifelse(plot_data$人数 > 0, 
                                               round(plot_data$均分, 1), 
                                               "")
            }
            
            # 计算每个X类别的最大人数（所有Y变量中人数最多的）
            x_category_totals <- plot_data %>%
                group_by(X类别) %>%
                summarise(最大人数 = max(人数, na.rm = TRUE), .groups = "drop")
            
            # 处理X轴标签：使用与单变量相同的分段逻辑（在'（'或'('前换行；每段>8字符再平均分为两行），并在末尾添加N=最大人数
            x_labels <- levels(plot_data$X类别)
            x_labels_processed <- sapply(x_labels, function(label) {
                label_str <- as.character(label)

                # 获取该X类别的最大人数
                max_n <- x_category_totals$最大人数[x_category_totals$X类别 == label]
                max_n <- ifelse(length(max_n) > 0, max_n[1], 0)

                # 第一步：检查是否存在"（"或"("字符，如果有，在这些字符前分段
                if (grepl("（|\\(", label_str)) {
                    pos1 <- regexpr("（", label_str)[1]
                    pos2 <- regexpr("\\(", label_str)[1]
                    if (pos1 > 0 && pos2 > 0) {
                        split_pos <- min(pos1, pos2)
                    } else if (pos1 > 0) {
                        split_pos <- pos1
                    } else {
                        split_pos <- pos2
                    }
                    part1 <- substr(label_str, 1, split_pos - 1)
                    part2 <- substr(label_str, split_pos, nchar(label_str))
                    segments <- c(part1, part2)
                } else {
                    segments <- label_str
                }

                # 第二步：对每一段，如果字符数>8，平均分成2段
                result_segments <- character()
                for (seg in segments) {
                    seg_len <- nchar(seg)
                    if (seg_len > 9) {
                        mid_pos <- ceiling(seg_len / 2)
                        seg1 <- substr(seg, 1, mid_pos)
                        seg2 <- substr(seg, mid_pos + 1, seg_len)
                        result_segments <- c(result_segments, seg1, seg2)
                    } else {
                        result_segments <- c(result_segments, seg)
                    }
                }

                label_with_newlines <- paste(result_segments, collapse = "\n")
                # 添加N=最大人数
                paste0(label_with_newlines, "\nN=", max_n)
            })
            
            # 分组条形图：使用position_dodge
            final_plot <- ggplot(plot_data, aes(x = X类别, y = 均分, fill = Y名称, group = Y名称)) +
                geom_bar(stat = "identity", position = position_dodge(width = 0.7), width = 0.6) +
                scale_fill_manual(values = color_mapping_y, name = "") +
                scale_x_discrete(labels = x_labels_processed) +
                # 均分标注（N>0时显示）
                geom_text(aes(label = label_text, group = Y名称), 
                         position = position_dodge(width = 0.7), vjust = -0.5, size = 3) +
                labs(caption = plot_title,
                     x = "", y = "") +
                scale_y_continuous(limits = c(0, y_upper_limit), 
                                  breaks = if(is_figure_type) y_breaks else waiver(),
                                  labels = if(is_figure_type && has_figures_with_dot) {
                                      function(x) paste0(x, "%")
                                  } else if(is_figure_type) {
                                      function(x) as.character(x)
                                  } else {
                                      waiver()
                                  },
                                  expand = c(0, 0)) +
                theme_minimal() +
                theme(legend.position = "bottom",
                      plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                      plot.caption.position = "plot",  # 相对于整个绘图区域居中
                      axis.text.x = element_text(angle = 0, vjust = 1, margin = margin(t = 12), family = "PingFang SC", lineheight = 1.2),
                      legend.text = element_text(family = "PingFang SC", size = 9),
                      legend.title = element_text(family = "STKaiti", size = 10),
                      legend.key.height = unit(0.5, "lines"),  # 图例方块高度为原来的1/2
                      legend.key.width = unit(1, "lines"),  # 图例方块宽度保持不变
                      panel.grid = element_blank(),  # 去掉所有背景网格线
                      axis.line = element_line(color = "black"))  # 添加X轴和Y轴线
        }
        
        return(list(table = result_table, plot = final_plot))
    }, error = function(e) {
        warning(paste("第", i, "行：difference_class函数执行失败：", e$message))
        return(NULL)
    })
}

# 11. ANOVA_scores函数
generate_ANOVA_scores <- function(dat, index_report_row, i, color_palette) {
    tryCatch({
        dim_or_item <- index_report_row$dim_or_item
        if (is.na(dim_or_item) || dim_or_item == "") {
            warning(paste("第", i, "行：dim_or_item为空"))
            return(NULL)
        }
        
        # 获取报告维度
        dim_or_item_value <- index_report_row$报告维度
        if (is.na(dim_or_item_value) || dim_or_item_value == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 确定Y变量（连续变量）
        if (str_detect(dim_or_item_value, "总分|量尺分|标准分")) {
            Y_col <- dim_or_item_value
        } else {
            Y_col <- paste0(dim_or_item_value, "_Score")
        }
        
        if (!Y_col %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到Y变量", Y_col))
            return(NULL)
        }
        
        # 获取X变量（分类变量）
        X_vars <- index_report_row$交叉或分类变量
        # X_vars <- strsplit(X_vars_str, "、", fixed = TRUE)[[1]]
        # X_vars <- trimws(X_vars)


        
        # 初始化结果表格
        result_table <- data.frame()
        # 初始化事后检验表格列表
        posthoc_tables <- list()
        
        # 对每个X变量进行ANOVA分析
        for (X_var in X_vars) {
            #  确定X变量（分类变量）
            if (dim_or_item == "dim") {
                X_var <- paste0(X_var, "_Class")
            } else {
                # 对于item类型，使用模糊匹配查找列名（处理括号问题）
                all_cols <- colnames(dat)
                # 先尝试精确匹配
                if (X_var %in% all_cols) {
                    X_var <- X_var
                } else {
                    # 使用模糊匹配（fixed = TRUE 避免正则表达式问题）
                    matching_cols <- all_cols[grepl(X_var, all_cols, fixed = TRUE)]
                    if (length(matching_cols) > 0) {
                        # 选择最匹配的（完全匹配或最短的）
                        exact_match <- matching_cols[matching_cols == X_var]
                        if (length(exact_match) > 0) {
                            X_var <- exact_match[1]
                        } else {
                            X_var <- matching_cols[1]
                        }
                    } else {
                        warning(paste("第", i, "行：未找到X变量", X_var))
                        return(NULL)
                    }
                }
            }

            if (!X_var %in% colnames(dat)) {
                warning(paste("第", i, "行：未找到X变量", X_var))
                next
            }
            
            # 获取X变量的所有类别
            # 如果是factor，使用levels；否则使用unique
            if (is.factor(dat[[X_var]])) {
                X_categories <- levels(dat[[X_var]])
            } else {
                X_categories <- unique(dat[[X_var]])
                X_categories <- X_categories[!is.na(X_categories)]
            }
            
            if (length(X_categories) < 2) {
                warning(paste("第", i, "行：X变量", X_var, "的类别数少于2"))
                next
            }
            
            # 判断是否为"区市"，使用不同的检验逻辑
            # is_qu_shi <- (X_var == "区市")
            
            # if (is_qu_shi) {
            #     # 区市：使用单样本t检验，每个区市与总体均值对比
            #     # 计算总体均值（所有数据的均值）
            #     overall_data <- dat[!is.na(dat[[Y_col]]), ]
            #     overall_mean <- mean(overall_data[[Y_col]], na.rm = TRUE)
                
            #     # 计算各组的统计量并进行单样本t检验
            #     for (cat in X_categories) {
            #         dat_subset <- dat[dat[[X_var]] == cat & !is.na(dat[[X_var]]), ]
            #         y_values <- dat_subset[[Y_col]]
            #         y_values <- y_values[!is.na(y_values)]
                    
            #         if (length(y_values) > 0) {
            #             # 进行单样本t检验（与总体均值对比）
            #             t_test_result <- tryCatch({
            #                 t.test(y_values, mu = overall_mean)
            #             }, error = function(e) {
            #                 return(NULL)
            #             })
                        
            #             # 计算统计量
            #             cat_mean <- mean(y_values)
            #             cat_sd <- sd(y_values)
            #             cat_n <- length(y_values)
                        
            #             # 计算T值和Cohen's d
            #             if (!is.null(t_test_result)) {
            #                 t_value <- round(t_test_result$statistic, 3)
            #                 p_value <- t_test_result$p.value
                            
            #                 # Cohen's d = (样本均值 - 总体均值) / 样本标准差
            #                 cohens_d <- round((cat_mean - overall_mean) / cat_sd, 3)
                            
            #                 # 显著性标记
            #                 sig_label <- ""
            #                 if (!is.na(p_value)) {
            #                     if (p_value < 0.001) {
            #                         sig_label <- "***"
            #                     } else if (p_value < 0.01) {
            #                         sig_label <- "**"
            #                     } else if (p_value < 0.05) {
            #                         sig_label <- "*"
            #                     } else {
            #                         sig_label <- "ns"
            #                     }
            #                 }
            #             } else {
            #                 t_value <- NA
            #                 cohens_d <- NA
            #                 sig_label <- ""
            #             }
                        
            #             result_table <- rbind(result_table, data.frame(
            #                 类别 = as.character(cat),
            #                 N = cat_n,
            #                 均值 = round(cat_mean, 2),
            #                 标准差 = round(cat_sd, 2),
            #                 T值 = ifelse(is.na(t_value), "", as.character(t_value)),
            #                 "Cohen's d" = ifelse(is.na(cohens_d), "", as.character(cohens_d)),
            #                 显著性 = sig_label,
            #                 stringsAsFactors = FALSE,
            #                 check.names = FALSE
            #             ))
            #         }
            #     }
            # } else {
                # 非区市：保持原有逻辑
                # 计算各组的统计量
                for (cat in X_categories) {
                    dat_subset <- dat[dat[[X_var]] == cat & !is.na(dat[[X_var]]), ]
                    y_values <- dat_subset[[Y_col]]
                    y_values <- y_values[!is.na(y_values)]
                    
                    if (length(y_values) > 0) {
                        result_table <- rbind(result_table, data.frame(
                            # 分组变量 = X_var,
                            类别 = as.character(cat),
                            N = length(y_values),
                            均值 = round(mean(y_values), 2),
                            标准差 = round(sd(y_values), 2),
                            stringsAsFactors = FALSE
                        ))
                    }
                }
            
            # } ###这是上面那个isqushi的括号
            
            # 进行ANOVA检验（仅当不是区市时）
            # if (!is_qu_shi) {
                aov_data <- dat[!is.na(dat[[X_var]]) & !is.na(dat[[Y_col]]), ] %>%
                    select(all_of(c(X_var, Y_col)))
                
                # 将类别名称中的"-"替换为"—"，避免事后检验拆分时出错
                aov_data[[X_var]] <- gsub("-", "—", aov_data[[X_var]])
                colnames(aov_data) <- c(paste0("X_var_temp_name", 1:length(X_var)), "Y_var_temp_name")

                if (nrow(aov_data) > 0 && length(X_categories) >= 2) {
                    if (length(X_categories) == 2) {
                        # t检验
                        group1 <- aov_data[aov_data[[paste0("X_var_temp_name", 1:length(X_var))]] == X_categories[1], "Y_var_temp_name"]
                        group2 <- aov_data[aov_data[[paste0("X_var_temp_name", 1:length(X_var))]] == X_categories[2], "Y_var_temp_name"]
                        group1 <- group1[!is.na(group1)]
                        group2 <- group2[!is.na(group2)]
                        
                        if (length(group1) > 0 && length(group2) > 0) {
                            t_test <- t.test(group1, group2)
                            # 计算效应量（Cohen's d）
                            pooled_sd <- sqrt(((length(group1) - 1) * var(group1) + 
                                            (length(group2) - 1) * var(group2)) / 
                                            (length(group1) + length(group2) - 2))
                            cohens_d <- abs(mean(group1) - mean(group2)) / pooled_sd
                            
                            result_table <- rbind(result_table, data.frame(
                                # 分组变量 = X_var,
                                类别 = "检验结果",
                                N = paste0("t=", round(t_test$statistic, 3)),
                                均值 = paste0("p=", format.pval(t_test$p.value, digits = 3)),
                                标准差 = paste0("d=", round(cohens_d, 3)),
                                stringsAsFactors = FALSE
                            ))
                        }
                    } else {
                        # ANOVA
                        aov_result <- aov(as.formula(paste("Y_var_temp_name", "~", "X_var_temp_name1")), data = aov_data)
                        aov_summary <- summary(aov_result)
                        F_value <- aov_summary[[1]][["F value"]][1]
                        p_value <- aov_summary[[1]][["Pr(>F)"]][1]
                        
                        # 计算效应量（eta squared）
                        SS_between <- aov_summary[[1]][["Sum Sq"]][1]
                        SS_total <- sum(aov_summary[[1]][["Sum Sq"]])
                        eta_squared <- SS_between / SS_total
                        
                        result_table <- rbind(result_table, data.frame(
                            # 分组变量 = gsub("_Class", "", X_var),
                            类别 = "检验结果",
                            N = paste0("F=", round(F_value, 3)),
                            均值 = paste0("p=", format.pval(p_value, digits = 3)),
                            标准差 = paste0("η²=", round(eta_squared, 3)),
                            stringsAsFactors = FALSE
                        ))
                        
                        # 如果ANOVA显著（p < 0.05），进行事后检验（Tukey HSD）
                        if (!is.na(p_value) && p_value < 0.05) {
                            # 进行Tukey HSD检验
                            tukey_result <- TukeyHSD(aov_result)
                            tukey_df <- as.data.frame(tukey_result[["X_var_temp_name1"]])
                            
                            # 获取各组均值和标准差（用于事后检验表格）
                            # 注意：aov_data中的类别名称已经将"-"替换为"—"
                            group_means <- aggregate(aov_data[["Y_var_temp_name"]], by = list(aov_data[["X_var_temp_name1"]]), FUN = mean, na.rm = TRUE)
                            group_sds <- aggregate(aov_data[["Y_var_temp_name"]], by = list(aov_data[["X_var_temp_name1"]]), FUN = sd, na.rm = TRUE)
                            colnames(group_means) <- c("类别", "均值")
                            colnames(group_sds) <- c("类别", "标准差")
                            group_stats <- merge(group_means, group_sds, by = "类别")
                            
                            # 创建事后检验表格
                            posthoc_table <- data.frame(
                                对比类别1 = character(),
                                对比类别2 = character(),
                                "类别1\n均值（标准差）" = character(),
                                "类别2\n均值（标准差）" = character(),
                                差值 = character(),
                                stringsAsFactors = FALSE,
                                check.names = FALSE
                            )
                            
                            # 提取对比对和p值
                            for (row_idx in 1:nrow(tukey_df)) {
                                # 提取对比对名称（格式如"类别1-类别2"）
                                comparison <- rownames(tukey_df)[row_idx]
                                comparison_parts <- strsplit(comparison, "-")[[1]]
                                cat1 <- trimws(comparison_parts[1])
                                cat2 <- trimws(comparison_parts[2])
                                
                                # 获取差值
                                diff_value <- tukey_df$diff[row_idx]
                                
                                # 获取p值并添加显著性标记
                                p_val <- tukey_df$`p adj`[row_idx]
                                sig_stars <- ""
                                if (!is.na(p_val)) {
                                    if (p_val < 0.001) {
                                        sig_stars <- "***"
                                    } else if (p_val < 0.01) {
                                        sig_stars <- "**"
                                    } else if (p_val < 0.05) {
                                        sig_stars <- "*"
                                    }
                                }
                                
                                # 获取类别1和类别2的均值和标准差
                                cat1_stats <- group_stats[group_stats$类别 == cat1, ]
                                cat2_stats <- group_stats[group_stats$类别 == cat2, ]
                                
                                cat1_mean_sd <- ""
                                cat2_mean_sd <- ""
                                if (nrow(cat1_stats) > 0) {
                                    cat1_mean_sd <- paste0(round(cat1_stats$均值, 2), "（", round(cat1_stats$标准差, 2), "）")
                                }
                                if (nrow(cat2_stats) > 0) {
                                    cat2_mean_sd <- paste0(round(cat2_stats$均值, 2), "（", round(cat2_stats$标准差, 2), "）")
                                }
                                
                                # 构建差值字符串（带显著性标记）
                                diff_str <- paste0(round(diff_value, 2), sig_stars)
                                
                                # 添加到事后检验表格
                                posthoc_table <- rbind(posthoc_table, data.frame(
                                    对比类别1 = cat1,
                                    对比类别2 = cat2,
                                    "类别1\n均值（标准差）" = cat1_mean_sd,
                                    "类别2\n均值（标准差）" = cat2_mean_sd,
                                    差值 = diff_str,
                                    stringsAsFactors = FALSE,
                                    check.names = FALSE
                                ))
                            }
                            
                            # 将事后检验表格添加到列表（使用X_var作为key）
                            if (nrow(posthoc_table) > 0) {
                                posthoc_tables[[X_var]] <- posthoc_table
                            }
                        }
                    }
                }
            # } # 这是isqushi的括号
        }
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_11_ANOVA_scores.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 如果有事后检验表格，保存并返回
        if (length(posthoc_tables) > 0) {
            # 合并所有事后检验表格（如果有多个X变量）
            if (length(posthoc_tables) == 1) {
                combined_posthoc <- posthoc_tables[[1]]
            } else {
                # 多个X变量时，合并所有事后检验表格
                combined_posthoc <- do.call(rbind, posthoc_tables)
            }
            write.csv(combined_posthoc, paste0(table_path, "/", i, "_11_ANOVA_scores_posthoc.csv"), 
                      row.names = FALSE, fileEncoding = "UTF-8")
            return(list(table = result_table, posthoc_table = combined_posthoc))
        } else {
            return(result_table)
        }
    }, error = function(e) {
        warning(paste("第", i, "行：ANOVA_scores函数执行失败：", e$message))
        return(NULL)
    })
}

# 12. linear_regression函数
generate_linear_regression <- function(dat, index_report_row, i, color_palette) {
    tryCatch({
        dim_or_item <- index_report_row$dim_or_item
        if (is.na(dim_or_item) || dim_or_item == "") {
            warning(paste("第", i, "行：dim_or_item为空"))
            return(NULL)
        }
        
        # 获取报告维度
        dim_or_item_value <- index_report_row$报告维度
        if (is.na(dim_or_item_value) || dim_or_item_value == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 确定Y变量（连续变量）
        if (dim_or_item == "dim") {
            Y_col <- paste0(dim_or_item_value, "_Score")
        } else {
            warning(paste("第", i, "行：linear_regression只支持dim类型"))
            return(NULL)
        }
        
        if (!Y_col %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到Y变量", Y_col))
            return(NULL)
        }
        
        # 获取X变量
        X_vars_str <- index_report_row$交叉或分类变量
        if (is.na(X_vars_str) || X_vars_str == "") {
            warning(paste("第", i, "行：交叉或分类变量为空"))
            return(NULL)
        }
        
        X_vars <- strsplit(X_vars_str, "、", fixed = TRUE)[[1]]
        X_vars <- trimws(X_vars)
        
        # 构建X变量列名（加上"_Score"后缀）
        X_cols <- paste0(X_vars, "_Score")
        
        # 检查哪些X变量存在
        existing_X_cols <- X_cols[X_cols %in% colnames(dat)]
        if (length(existing_X_cols) == 0) {
            warning(paste("第", i, "行：未找到任何X变量"))
            return(NULL)
        }
        
        # 控制变量（排除"区市"）
        control_vars <- basic_vars[basic_vars != "区市"]
        existing_controls <- control_vars[control_vars %in% colnames(dat)]
        
        # 准备回归数据
        reg_data <- dat[, c(Y_col, existing_X_cols, existing_controls), drop = FALSE]
        
        # 只对Y变量和X变量要求完整，控制变量允许缺失（回归时会自动处理）
        required_vars <- c(Y_col, existing_X_cols)
        complete_rows <- complete.cases(reg_data[, required_vars, drop = FALSE])
        reg_data <- reg_data[complete_rows, ]
        
        if (nrow(reg_data) == 0) {
            warning(paste("第", i, "行：没有完整的数据进行回归分析（Y变量和X变量都缺失）"))
            return(NULL)
        }
        
        # 检查因子变量是否有至少两个水平，排除只有一个水平的因子变量
        valid_vars <- c()
        all_vars <- c(existing_X_cols, existing_controls)
        
        for (var in all_vars) {
            if (var %in% colnames(reg_data)) {
                if (is.factor(reg_data[[var]])) {
                    # 检查因子变量的水平数
                    n_levels <- length(unique(reg_data[[var]]))
                    if (n_levels >= 2) {
                        valid_vars <- c(valid_vars, var)
                    } else {
                        warning(paste("第", i, "行：变量", var, "只有一个水平，已排除"))
                    }
                } else {
                    # 非因子变量直接添加
                    valid_vars <- c(valid_vars, var)
                }
            }
        }
        
        if (length(valid_vars) == 0) {
            warning(paste("第", i, "行：没有有效的变量进行回归分析"))
            return(NULL)
        }
        
        # 构建回归公式
        formula_str <- paste(Y_col, "~", paste(valid_vars, collapse = " + "))
        
        # 进行多元回归
        lm_result <- lm(as.formula(formula_str), data = reg_data)
        lm_summary <- summary(lm_result)
        
        # 控制变量名称映射
        control_var_name_mapping <- c(
            "Gen" = "性别",
            "Loc" = "居住地",
            "Fam" = "家庭结构",
            "Sim" = "子女数量",
            "Edu_m" = "母亲学历",
            "Edu_f" = "父亲学历",
            "SES" = "家庭教育投入",
            "Age" = "年龄",
            "Exp" = "教龄",
            "Edu" = "学历",
            "Tit" = "职称"
        )
        
        # 提取结果（变量类型放在第一列）
        result_table <- data.frame(
            变量类型 = character(),
            变量 = character(),
            系数 = numeric(),
            标准误 = numeric(),
            t值 = numeric(),
            p值 = numeric(),
            显著性 = character(),
            stringsAsFactors = FALSE
        )
        
        # 提取X变量的系数
        coef_table <- lm_summary$coefficients
        for (X_col in existing_X_cols) {
            if (X_col %in% rownames(coef_table)) {
                coef_row <- coef_table[X_col, ]
                p_val <- coef_row[4]
                sig <- ""
                if (p_val < 0.001) sig <- "***"
                else if (p_val < 0.01) sig <- "**"
                else if (p_val < 0.05) sig <- "*"
                
                result_table <- rbind(result_table, data.frame(
                    变量类型 = "预测变量",
                    变量 = gsub("_Score$", "", X_col),
                    系数 = round(coef_row[1], 3),
                    标准误 = round(coef_row[2], 3),
                    t值 = round(coef_row[3], 3),
                    p值 = format.pval(p_val, digits = 3),
                    显著性 = sig,
                    stringsAsFactors = FALSE
                ))
            }
        }
        
        # 提取控制变量的系数
        # 获取实际参与回归的控制变量（valid_vars中除了X变量之外的部分）
        valid_controls <- setdiff(valid_vars, existing_X_cols)
        
        for (control_var in valid_controls) {
            # 对于因子变量，可能会有多个系数（每个水平一个，除了参考水平）
            # 需要检查coef_table中所有以control_var开头的行
            matching_rows <- rownames(coef_table)[grepl(paste0("^", control_var), rownames(coef_table))]
            
            if (length(matching_rows) > 0) {
                for (row_name in matching_rows) {
                    coef_row <- coef_table[row_name, ]
                    p_val <- coef_row[4]
                    sig <- ""
                    if (p_val < 0.001) sig <- "***"
                    else if (p_val < 0.01) sig <- "**"
                    else if (p_val < 0.05) sig <- "*"
                    
                    # 提取变量名（对于因子变量，row_name可能是"Gen女"这样的格式）
                    # 转换控制变量名称并添加"-"分隔符
                    if (row_name == control_var) {
                        # 非因子变量（连续变量）
                        var_name <- ifelse(control_var %in% names(control_var_name_mapping),
                                          control_var_name_mapping[[control_var]],
                                          control_var)
                    } else {
                        # 因子变量：提取水平部分，并转换变量名
                        # row_name格式可能是"Gen女"、"Loc镇驻地"等
                        level_part <- sub(paste0("^", control_var), "", row_name)
                        base_name <- ifelse(control_var %in% names(control_var_name_mapping),
                                           control_var_name_mapping[[control_var]],
                                           control_var)
                        var_name <- paste0(base_name, "-", level_part)
                    }
                    
                    result_table <- rbind(result_table, data.frame(
                        变量类型 = "控制变量",
                        变量 = var_name,
                        系数 = round(coef_row[1], 3),
                        标准误 = round(coef_row[2], 3),
                        t值 = round(coef_row[3], 3),
                        p值 = format.pval(p_val, digits = 3),
                        显著性 = sig,
                        stringsAsFactors = FALSE
                    ))
                }
            }
        }
        
        # 添加模型总体信息
        result_table <- rbind(result_table, data.frame(
            变量类型 = "模型信息",
            变量 = "模型总体",
            系数 = NA,
            标准误 = NA,
            t值 = NA,
            p值 = format.pval(pf(lm_summary$fstatistic[1], lm_summary$fstatistic[2], 
                                lm_summary$fstatistic[3], lower.tail = FALSE), digits = 3),
            显著性 = "",
            stringsAsFactors = FALSE
        ))
        
        result_table <- rbind(result_table, data.frame(
            变量类型 = "模型信息",
            变量 = "R²",
            系数 = round(lm_summary$r.squared, 3),
            标准误 = NA,
            t值 = NA,
            p值 = NA,
            显著性 = "",
            stringsAsFactors = FALSE
        ))
        
        result_table <- rbind(result_table, data.frame(
            变量类型 = "模型信息",
            变量 = "N",
            系数 = nrow(reg_data),
            标准误 = NA,
            t值 = NA,
            p值 = NA,
            显著性 = "",
            stringsAsFactors = FALSE
        ))
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_12_linear_regression.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        return(result_table)
    }, error = function(e) {
        warning(paste("第", i, "行：linear_regression函数执行失败：", e$message))
        return(NULL)
    })
}

# 13. correlation_point函数
generate_correlation_point <- function(dat, index_report_row, i, color_palette) {
    tryCatch({
        dim_or_item <- index_report_row$dim_or_item
        if (is.na(dim_or_item) || dim_or_item == "") {
            warning(paste("第", i, "行：dim_or_item为空"))
            return(NULL)
        }
        
        # 获取报告维度
        dim_or_item_value <- index_report_row$报告维度
        if (is.na(dim_or_item_value) || dim_or_item_value == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 确定X变量（连续变量）
        if (dim_or_item == "dim") {
            X_col <- paste0(dim_or_item_value, "_Score")
        } else {
            warning(paste("第", i, "行：correlation_point只支持dim类型"))
            return(NULL)
        }
        
        if (!X_col %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到X变量", X_col))
            return(NULL)
        }
        
        # 获取Y变量
        Y_vars_str <- index_report_row$交叉或分类变量
        if (is.na(Y_vars_str) || Y_vars_str == "") {
            warning(paste("第", i, "行：交叉或分类变量为空"))
            return(NULL)
        }
        
        Y_vars <- strsplit(Y_vars_str, "、", fixed = TRUE)[[1]]
        Y_vars <- trimws(Y_vars)
        
        # 构建Y变量列名（加上"_Score"后缀）
        Y_cols <- paste0(Y_vars, "_Score")
        
        # 检查哪些Y变量存在
        existing_Y_cols <- Y_cols[Y_cols %in% colnames(dat)]
        if (length(existing_Y_cols) == 0) {
            warning(paste("第", i, "行：未找到任何Y变量"))
            return(NULL)
        }
        
        plots_list <- list()
        
        for (Y_col in existing_Y_cols) {
            Y_name <- gsub("_Score$", "", Y_col)
            
            # 准备数据
            plot_data <- dat[, c(X_col, Y_col)]
            plot_data <- plot_data[complete.cases(plot_data), ]
            
            if (nrow(plot_data) == 0) {
                next
            }
            
            # 计算相关系数和回归
            cor_result <- cor.test(plot_data[[X_col]], plot_data[[Y_col]])
            lm_result <- lm(as.formula(paste(Y_col, "~", X_col)), data = plot_data)
            lm_summary <- summary(lm_result)
            
            # 构建标注文本
            X_name <- gsub("_Score$", "", X_col)
            cor_coef <- cor_result$estimate
            cor_p <- cor_result$p.value
            cor_sig <- ""
            if (cor_p < 0.001) cor_sig <- "***"
            else if (cor_p < 0.01) cor_sig <- "**"
            else if (cor_p < 0.05) cor_sig <- "*"
            
            reg_eq <- paste0("y = ", round(lm_result$coefficients[2], 3), "x + ", 
                            round(lm_result$coefficients[1], 3))
            reg_p <- lm_summary$coefficients[2, 4]
            reg_sig <- ""
            if (reg_p < 0.001) reg_sig <- "***"
            else if (reg_p < 0.01) reg_sig <- "**"
            else if (reg_p < 0.05) reg_sig <- "*"
            
            # 构建标注文本（如果有显著性标记，就不显示p值行）
            label_lines <- c(
                paste0("回归方程：", reg_eq, reg_sig)
            )
            
            # 如果回归方程没有显著性标记，才显示回归显著性p值
            if (reg_sig == "") {
                label_lines <- c(label_lines, paste0("回归显著性：p=", format.pval(reg_p, digits = 3)))
            }
            
            label_lines <- c(label_lines, paste0("相关系数：r=", round(cor_coef, 3), cor_sig))
            
            # 如果相关系数没有显著性标记，才显示相关显著性p值
            if (cor_sig == "") {
                label_lines <- c(label_lines, paste0("相关显著性：p=", format.pval(cor_p, digits = 3)))
            }
            
            label_text <- paste(label_lines, collapse = "\n")
            
            # 确定title
            if (length(existing_Y_cols) == 1) {
                plot_title <- ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题)
            } else {
                plot_title <- Y_name
            }
            
            # 绘制散点图（不round，因为是连续变量）
            p <- ggplot(plot_data, aes(x = !!sym(X_col), y = !!sym(Y_col))) +
                geom_point(alpha = 0.5, color = color_palette$color_1[1]) +
                geom_smooth(method = "lm", se = TRUE, color = color_palette$color_2[2]) +
                labs(caption = plot_title,
                     subtitle = label_text,
                     x = X_name,
                     y = Y_name) +
                theme_minimal() +
                theme(plot.caption = element_text(hjust = 0.5, size = 11, family = "STKaiti"),
                      plot.caption.position = "plot",  # 相对于整个绘图区域居中
                      plot.subtitle = element_text(hjust = 0, size = 9, family = "STKaiti"),
                      text = element_text(family = "PingFang SC"),
                      axis.text = element_text(family = "PingFang SC"),
                      axis.title = element_text(family = "PingFang SC"))
            
            plots_list[[Y_name]] <- p
        }
        
        # 如果多个Y变量，合并图片
        if (length(plots_list) == 1) {
            final_plot <- plots_list[[1]]
        } else {
            n_plots <- length(plots_list)
            n_cols <- min(2, n_plots)
            n_rows <- ceiling(n_plots / n_cols)
            # 不设置heights参数，让arrangeGrob根据每个子图的原始尺寸自动调整，避免拉伸
            # 添加总标题（放在下面）
            main_title <- ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题)
            if (main_title != "") {
                final_plot <- arrangeGrob(
                    grobs = plots_list,
                    ncol = n_cols,
                    nrow = n_rows,
                    bottom = textGrob(main_title, gp = gpar(fontsize = 14, fontface = "bold", fontfamily = "GB1"))
                )
            } else {
                final_plot <- arrangeGrob(
                    grobs = plots_list,
                    ncol = n_cols,
                    nrow = n_rows
                )
            }
        }
        
        return(list(plot = final_plot))
    }, error = function(e) {
        warning(paste("第", i, "行：correlation_point函数执行失败：", e$message))
        return(NULL)
    })
}

# 14. correlation_matrix函数
generate_correlation_matrix <- function(dat, index_report_row, i, color_palette) {
    tryCatch({
        dim_or_item <- index_report_row$dim_or_item
        if (is.na(dim_or_item) || dim_or_item == "") {
            warning(paste("第", i, "行：dim_or_item为空"))
            return(NULL)
        }
        
        # 获取报告维度（可能多个，顿号分割）
        dims_str <- index_report_row$报告维度
        if (is.na(dims_str) || dims_str == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        dims <- strsplit(dims_str, "、", fixed = TRUE)[[1]]
        dims <- trimws(dims)
        
        # 构建X变量列名（加上"_Score"后缀）
        X_cols <- paste0(dims, "_Score")
        
        # 检查哪些X变量存在
        existing_X_cols <- X_cols[X_cols %in% colnames(dat)]
        if (length(existing_X_cols) == 0) {
            warning(paste("第", i, "行：未找到任何X变量"))
            return(NULL)
        }
        
        # 获取Y变量
        Y_vars_str <- index_report_row$交叉或分类变量
        if (is.na(Y_vars_str) || Y_vars_str == "") {
            warning(paste("第", i, "行：交叉或分类变量为空"))
            return(NULL)
        }
        
        Y_vars <- strsplit(Y_vars_str, "、", fixed = TRUE)[[1]]
        Y_vars <- trimws(Y_vars)
        
        # 构建Y变量列名（加上"_Score"后缀）
        Y_cols <- paste0(Y_vars, "_Score")
        
        # 检查哪些Y变量存在
        existing_Y_cols <- Y_cols[Y_cols %in% colnames(dat)]
        if (length(existing_Y_cols) == 0) {
            warning(paste("第", i, "行：未找到任何Y变量"))
            return(NULL)
        }
        
        # 准备数据
        cor_data <- dat[, c(existing_X_cols, existing_Y_cols), drop = FALSE]
        cor_data <- cor_data[complete.cases(cor_data), ]
        
        if (nrow(cor_data) == 0) {
            warning(paste("第", i, "行：没有完整的数据进行相关分析"))
            return(NULL)
        }
        
        # 计算相关系数矩阵
        cor_matrix <- cor(cor_data)
        
        # 计算显著性
        cor_p_matrix <- matrix(NA, nrow = nrow(cor_matrix), ncol = ncol(cor_matrix))
        for (i_x in seq_along(existing_X_cols)) {
            for (i_y in seq_along(existing_Y_cols)) {
                x_col <- existing_X_cols[i_x]
                y_col <- existing_Y_cols[i_y]
                if (x_col != y_col) {
                    cor_test <- cor.test(cor_data[[x_col]], cor_data[[y_col]])
                    cor_p_matrix[i_x, length(existing_X_cols) + i_y] <- cor_test$p.value
                }
            }
        }
        
        # 提取X和Y之间的相关系数
        cor_subset <- cor_matrix[seq_along(existing_X_cols), 
                                 (length(existing_X_cols) + 1):ncol(cor_matrix), 
                                 drop = FALSE]
        p_subset <- cor_p_matrix[seq_along(existing_X_cols), 
                                (length(existing_X_cols) + 1):ncol(cor_matrix), 
                                drop = FALSE]
        
        # 构建结果表格
        result_table <- data.frame(
            X变量 = gsub("_Score$", "", existing_X_cols),
            stringsAsFactors = FALSE
        )
        
        for (i_y in seq_along(existing_Y_cols)) {
            Y_name <- gsub("_Score$", "", existing_Y_cols[i_y])
            cor_values <- cor_subset[, i_y]
            p_values <- p_subset[, i_y]
            
                # 添加显著性标记（保留3位小数）
                cor_with_sig <- sapply(seq_along(cor_values), function(j) {
                    cor_val <- cor_values[j]
                    p_val <- p_values[j]
                    sig <- ""
                    if (!is.na(p_val)) {
                        if (p_val < 0.001) sig <- "***"
                        else if (p_val < 0.01) sig <- "**"
                        else if (p_val < 0.05) sig <- "*"
                    }
                    paste0(round(cor_val, 3), sig)
                })
            
            result_table[[Y_name]] <- cor_with_sig
        }
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(result_table, paste0(table_path, "/", i, "_14_correlation_matrix.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        # 绘制热力图
        cor_plot_data <- cor_subset
        rownames(cor_plot_data) <- gsub("_Score$", "", existing_X_cols)
        colnames(cor_plot_data) <- gsub("_Score$", "", existing_Y_cols)
        
        # 使用ggplot2绘制热力图
        # 将矩阵转换为长格式数据
        plot_data <- expand.grid(X变量 = gsub("_Score$", "", existing_X_cols),
                                Y变量 = gsub("_Score$", "", existing_Y_cols))
        plot_data$相关系数 <- as.vector(cor_subset)
        
        # 获取对应的p值
        plot_data$p值 <- as.vector(p_subset)
        plot_data$显著性 <- ""
        plot_data$显著性[plot_data$p值 < 0.001] <- "***"
        plot_data$显著性[plot_data$p值 >= 0.001 & plot_data$p值 < 0.01] <- "**"
        plot_data$显著性[plot_data$p值 >= 0.01 & plot_data$p值 < 0.05] <- "*"
        
        plot_data$标签 <- paste0(round(plot_data$相关系数, 3), plot_data$显著性)
        
        # 根据X变量数量确定图的高度
        n_x_vars <- length(existing_X_cols)
        if (n_x_vars == 3) {
            plot_height <- 2  # 3个变量时高度为2（比默认小一倍）
        } else {
            plot_height <- max(3, n_x_vars * 0.5)  # 其他情况根据变量数动态调整
        }
        
        p <- ggplot(plot_data, aes(x = Y变量, y = X变量, fill = 相关系数)) +
            geom_tile(color = "white") +
            geom_text(aes(label = 标签), size = 4.5) +
            scale_fill_gradient2(low = color_palette$gradient_positive[1],
                               mid = "white",
                               high = color_palette$gradient_positive[2],
                               midpoint = 0) +
            labs(caption = ifelse(is.na(index_report_row$图题表题), "", index_report_row$图题表题),
                 x = "", y = "") +
            theme_minimal() +
            theme(axis.text.x = element_text(angle = 0),
                  plot.caption = element_text(hjust = 0.5, size = 12, family = "STKaiti"),
                  plot.caption.position = "plot")  # 相对于整个绘图区域居中
        
        # 设置高度属性
        attr(p, "plot_height") <- plot_height
        
        return(list(table = result_table, plot = p))
    }, error = function(e) {
        warning(paste("第", i, "行：correlation_matrix函数执行失败：", e$message))
        return(NULL)
    })
}

# 图表生成函数调度器 区级报告
generate_chart <- function(dat, index_report_row, index_item, i, color_palette, figures_with_dot = NULL, hide_other_labels = FALSE, target_district = NULL,
                           table_cnt_stu_left_vars = NULL, table_cnt_stu_right_vars = NULL,
                           table_cnt_tea_left_vars = NULL, table_cnt_tea_right_vars = NULL,
                           var_name_mapping = NULL, return_text_for_table_cnt_stu = FALSE,
                           is_three_level_compare = FALSE, dat_qd = NULL, dat_dist = NULL, school_name = NULL, grade_level = NULL, school_name_text = NULL) {
    chart_type <- index_report_row$图表类型
    if (is.na(chart_type) || chart_type == "") {
        return(NULL)
    }
    
    chart_type <- trimws(chart_type)
    
    if (chart_type == "Cronbach_alpha") {
        return(generate_Cronbach_alpha(dat, index_report_row, index_item, i, color_palette))
    } else if (chart_type == "simple_bar_dis_figures" || chart_type == "simple_bar_dis_figures_percent" || chart_type == "simple_bar_dis_score") {
        return(generate_simple_bar_dis_figures(dat, index_report_row, i, color_palette, figures_with_dot, hide_other_labels, target_district,
                                               is_three_level_compare, dat_qd, dat_dist, school_name))
    } else if (chart_type == "simple_bar_subdim_figures" || chart_type == "simple_bar_subdim_score") {
        return(generate_simple_bar_subdim_figures(dat, index_report_row, index_item, i, color_palette, figures_with_dot))
    } else if (chart_type == "table_figures") {
        return(generate_table_figures(dat, index_report_row, i, color_palette, figures_with_dot))
    } else if (chart_type == "table_dims_score" || chart_type == "table_dims_figure" || chart_type == "table_dims_figures_percent" || chart_type == "table_dims_figures") {
        return(generate_table_dims_score(dat, index_report_row, i, color_palette, figures_with_dot))
    } else if (chart_type == "table_basic_infor_figures") {
        return(generate_table_basic_infor_figures(dat, index_report_row, i, color_palette, figures_with_dot))
    } else if (chart_type == "table_items") {
        return(generate_table_items(dat, index_report_row, index_item, i, color_palette))
    } else if (chart_type == "table_dims_choice_percent") {
        return(generate_table_dims_choice_percent(dat, index_report_row, index_item, i, color_palette))
    } else if (chart_type == "table_items_score") {
        return(generate_table_items_score(dat, index_report_row, index_item, i, color_palette))
    } else if (chart_type == "simple_bar_items_score") {
        return(generate_simple_bar_items_score(dat, index_report_row, index_item, i, color_palette))
    } else if (chart_type == "table_score_dis") {
        return(generate_table_score_dis(dat, index_report_row, i, color_palette))
    } else if (chart_type == "table_cnt_stu") {
        return(generate_table_cnt_stu(dat, index_report_row, i, color_palette, 
                                      left_vars = table_cnt_stu_left_vars, 
                                      right_vars = table_cnt_stu_right_vars, 
                                      var_name_mapping = var_name_mapping,
                                      return_text = return_text_for_table_cnt_stu))
    } else if (chart_type == "table_cnt_tea") {
        return(generate_table_cnt_tea(dat, index_report_row, i, color_palette,
                                      left_vars = table_cnt_tea_left_vars, 
                                      right_vars = table_cnt_tea_right_vars, 
                                      var_name_mapping = var_name_mapping))
    } else if (chart_type == "multichoice_distribution" || chart_type == "multichoice_distribution_non_percent") {
        return(generate_multichoice_distribution(dat, index_report_row, i, color_palette))
    } else if (chart_type == "bar_chart_years") {
        return(generate_bar_chart_years(dat, index_report_row, i, color_palette))
    } else if (chart_type == "pie_distribution" || chart_type == "pie_distribution_trans_bar") {
        return(generate_pie_distribution(dat, index_report_row, index_item, i, color_palette))
    } else if (chart_type == "stack_bar_var_distribution") {
        return(generate_stack_bar_var_distribution(dat, index_report_row, index_item, i, color_palette, hide_other_labels, target_district,
                                                   is_three_level_compare, dat_qd, dat_dist, school_name))
    } else if (chart_type == "stack_bar_var_distribution_sch") {
        # 学校报告专用：与本函数相同，仅传本校 dat，不做三级对比
        return(generate_stack_bar_var_distribution(dat, index_report_row, index_item, i, color_palette, hide_other_labels, target_district,
                                                   FALSE, NULL, NULL, NULL))
    } else if (chart_type == "stack_bar_change_y") {
        return(generate_stack_bar_change_y(dat, index_report_row, index_item, i, color_palette,
                                          is_three_level_compare, dat_qd, dat_dist, school_name))
    } else if (chart_type == "stack_bar_subdim") {
        return(generate_stack_bar_subdim(dat, index_report_row, index_item, i, color_palette))
    } else if (chart_type == "stack_bar_choices_based") {
        return(generate_stack_bar_choices_based(dat, index_report_row, index_item, i, color_palette,
                                               is_three_level_compare, dat_qd, dat_dist, school_name))
    } else if (chart_type == "choices_pct") {
        return(generate_choices_pct(dat, index_report_row, index_item, i, color_palette))
    } else if (grepl("difference_class", chart_type)) {
        return(generate_difference_class(dat, index_report_row, index_item, i, color_palette))
    } else if (chart_type == "ANOVA_scores") {
        return(generate_ANOVA_scores(dat, index_report_row, i, color_palette))
    } else if (chart_type == "linear_regression") {
        return(generate_linear_regression(dat, index_report_row, i, color_palette))
    } else if (chart_type == "correlation_point") {
        return(generate_correlation_point(dat, index_report_row, i, color_palette))
    } else if (chart_type == "correlation_matrix") {
        return(generate_correlation_matrix(dat, index_report_row, i, color_palette))
    } else if (chart_type == "text_psy_tea_cnt") {
        return(generate_text_psy_tea_cnt(dat, index_report_row, i))
    } else if (chart_type == "text_psy_tea_cnt_sch") {
        return(generate_text_psy_tea_cnt_sch(dat, index_report_row, i))
    } else if (chart_type == "text_cnt_Chinese_tea") {
        return(generate_text_cnt_Chinese_tea(dat, index_report_row, i))
    } else if (chart_type == "text_cnt_total") {
        return(generate_text_cnt_total(dat, index_report_row, i, grade_level, school_name_text))
    } else if (chart_type == "text_tea_pys") {
        return(generate_text_tea_pys(dat, index_report_row, i))
    } else {
        warning(paste("第", i, "行：未知的图表类型", chart_type))
        return(NULL)
    }
}

# 生成心理健康教育教师配置文本
generate_text_psy_tea_cnt <- function(dat, index_report_row, i) {
    tryCatch({
        # 检查必要的列是否存在
        col_main_subject <- "5.（多选题）本学期你所交的主要学科是（多选题）"
        col_psy_subject <- "5.（多选题）本学期你所交的主要学科是（多选题）_心理健康教育"
        col_prep_time <- "15.本学期，您的备课时间是否足够？（单选题）"
        
        if (!col_main_subject %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到列", col_main_subject))
            return(NULL)
        }
        if (!col_prep_time %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到列", col_prep_time))
            return(NULL)
        }
        
        # 1. 计算专职教师数量：主学科完全等于"心理健康教育"
        full_time_teachers <- dat[dat[[col_main_subject]] == "心理健康教育" & !is.na(dat[[col_main_subject]]), ]
        full_time_cnt <- nrow(full_time_teachers)
        
        # 2. 计算兼职教师数量：心理健康教育列等于1，但主学科不等于"心理健康教育"
        if (col_psy_subject %in% colnames(dat)) {
            part_time_teachers <- dat[
                dat[[col_psy_subject]] == 1 & 
                !is.na(dat[[col_psy_subject]]) &
                dat[[col_main_subject]] != "心理健康教育" & 
                !is.na(dat[[col_main_subject]]), 
            ]
            part_time_cnt <- nrow(part_time_teachers)
        } else {
            warning(paste("第", i, "行：未找到列", col_psy_subject, "，兼职教师数量设为0"))
            part_time_cnt <- 0
        }
        
        # 3. 计算专职教师中备课时间比较充足或很充足的比例
        if (full_time_cnt > 0) {
            full_time_with_prep <- full_time_teachers[
                full_time_teachers[[col_prep_time]] %in% c("很足够", "比较足够") & 
                !is.na(full_time_teachers[[col_prep_time]]), 
            ]
            prep_sufficient_pct <- round(nrow(full_time_with_prep) / full_time_cnt * 100, 0)
            
            # 4. 计算专职教师中备课时间不太充足或完全不够的比例
            full_time_without_prep <- full_time_teachers[
                full_time_teachers[[col_prep_time]] %in% c("不太够", "完全不够") & 
                !is.na(full_time_teachers[[col_prep_time]]), 
            ]
            prep_insufficient_pct <- round(nrow(full_time_without_prep) / full_time_cnt * 100, 0)
        } else {
            warning(paste("第", i, "行：专职教师数量为0，无法计算备课时间比例"))
            prep_sufficient_pct <- 0
            prep_insufficient_pct <- 0
        }
        
        # 生成文本
        if (full_time_cnt == 0) {
            # 如果没有专职教师，直接返回简化文本
            text <- paste0("在心理健康教育上，本区（市）没有专职教师，共有兼职老师", part_time_cnt, "人。")
        } else {
            # 有专职教师时，根据备课时间情况生成文本
            text <- ifelse(prep_insufficient_pct == 0,
                paste0(
                    "在教师配置方面，高中心理健康教育专职教师", full_time_cnt, "人，兼职教师", part_time_cnt, "人。",
                    "所有的专职教师都表示备课时间比较充足或很充足。"
                ),
                paste0(
                    "在教师配置方面，高中心理健康教育专职教师", full_time_cnt, "人，兼职教师", part_time_cnt, "人。",
                    prep_sufficient_pct, "%的专职教师表示备课时间比较充足或很充足，",
                    prep_insufficient_pct, "%的专职教师表示备课时间完全或不太充足。"
                ))
        }
        
        # 返回一个包含text的对象
        return(list(text = text))
    }, error = function(e) {
        warning(paste("第", i, "行：text_psy_tea_cnt函数执行失败：", e$message))
        return(NULL)
    })
}

# 生成心理健康教育教师配置文本（校级版本）
generate_text_psy_tea_cnt_sch <- function(dat, index_report_row, i) {
    tryCatch({
        # 检查必要的列是否存在
        col_main_subject <- "5.（多选题）本学期你所交的主要学科是（多选题）"
        col_psy_subject <- "5.（多选题）本学期你所交的主要学科是（多选题）_心理健康教育"
        
        if (!col_main_subject %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到列", col_main_subject))
            return(NULL)
        }
        
        # 计算专职教师数量：主学科完全等于"心理健康教育"
        full_time_teachers <- dat[dat[[col_main_subject]] == "心理健康教育" & !is.na(dat[[col_main_subject]]), ]
        full_time_cnt <- nrow(full_time_teachers)
        
        # 生成文本
        if (full_time_cnt == 0) {
            text <- "本校没有专职的心理健康教育教师。"
        } else {
            text <- paste0("在教师配置方面，学校有心理健康教育专职教师", full_time_cnt, "人。")
        }
        
        # 返回一个包含text的对象
        return(list(text = text))
    }, error = function(e) {
        warning(paste("第", i, "行：text_psy_tea_cnt_sch函数执行失败：", e$message))
        return(NULL)
    })
}

# 生成中职二年级语文教师基本信息文本
generate_text_cnt_Chinese_tea <- function(dat, index_report_row, i) {
    tryCatch({
        # 检查必要的列是否存在
        if (!"Gen" %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到列Gen"))
            return(NULL)
        }
        if (!"Age" %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到列Age"))
            return(NULL)
        }
        
        # 计算总人数
        total_cnt <- nrow(dat)
        
        # 计算性别分布（使用sum避免as.numeric警告）
        male_cnt <- sum(dat$Gen == "男", na.rm = TRUE)
        female_cnt <- sum(dat$Gen == "女", na.rm = TRUE)
        male_pct <- round(male_cnt / total_cnt * 100, 1)
        female_pct <- round(female_cnt / total_cnt * 100, 1)
        
        # 计算年龄分布（使用sum避免as.numeric警告）
        age_20_29_cnt <- sum(dat$Age == "20-29岁", na.rm = TRUE)
        age_30_39_cnt <- sum(dat$Age == "30-39岁", na.rm = TRUE)
        age_40_49_cnt <- sum(dat$Age == "40-49岁", na.rm = TRUE)
        age_50plus_cnt <- sum(dat$Age == "50岁以上", na.rm = TRUE)
        
        age_20_29_pct <- round(age_20_29_cnt / total_cnt * 100, 1)
        age_30_39_pct <- round(age_30_39_cnt / total_cnt * 100, 1)
        age_40_49_pct <- round(age_40_49_cnt / total_cnt * 100, 1)
        age_50plus_pct <- round(age_50plus_cnt / total_cnt * 100, 1)
        
        # 生成文本
        text <- paste0("共有", total_cnt, "名中职二年级语文教师参加问卷调查，",
                      "有男性", male_cnt, "人，占比", male_pct, "%；",
                      "女性", female_cnt, "人，占比", female_pct, "%。",
                      "30岁以下的占", age_20_29_pct, "%；",
                      "30-39岁的占", age_30_39_pct, "%；",
                      "40-49岁的占", age_40_49_pct, "%；",
                      "50岁以上的占", age_50plus_pct, "%。")
        
        # 返回一个包含text的对象
        return(list(text = text))
    }, error = function(e) {
        warning(paste("第", i, "行：text_cnt_Chinese_tea函数执行失败：", e$message))
        return(NULL)
    })
}

# 生成总人数文本
generate_text_cnt_total <- function(dat, index_report_row, i, grade_level = NULL, school_name_text = NULL) {
    tryCatch({
        # 计算总人数
        total_cnt <- nrow(dat)
        
        # 根据报告维度处取到对象名
        # data_table <- if (!is.na(index_report_row$数据表对应)) index_report_row$数据表对应 else ""
        student_type <- index_report_row$报告维度
        
        # 暂时不要年级字段
        # grade_text <- if (!is.null(grade_level) && grade_level != "") grade_level else ""
        
        # 获取学校名称文本，如果未传入则默认为"本校"
        school_text <- if (!is.null(school_name_text) && school_name_text != "") school_name_text else "本校"
        
        # 生成文本：评估对象为{grade_level}{学生}，{school_name_text}共回收{学生}有效问卷{XX}份，有效率达100%。
        text <- paste0("评估对象为", student_type, "，", school_text, "共回收有效问卷", total_cnt, "份，有效率达100%。")
        
        # 返回一个包含text的对象
        return(list(text = text))
    }, error = function(e) {
        warning(paste("第", i, "行：text_cnt_total函数执行失败：", e$message))
        return(NULL)
    })
}

# 学校报告：教师心理健康态度/技能均值与达标分比较（纯文本）
generate_text_tea_pys <- function(dat, index_report_row, i) {
    tryCatch({
        col_att <- "心理健康态度_Score"
        col_skill <- "心理健康技能_Score"
        threshold_att <- 24
        threshold_skill <- 28
        
        if (is.null(dat) || !is.data.frame(dat) || nrow(dat) == 0) {
            warning(paste("第", i, "行：text_tea_pys 数据为空"))
            return(NULL)
        }
        if (!col_att %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到列", col_att))
            return(NULL)
        }
        if (!col_skill %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到列", col_skill))
            return(NULL)
        }
        
        mean_att <- mean(dat[[col_att]], na.rm = TRUE)
        mean_skill <- mean(dat[[col_skill]], na.rm = TRUE)
        if (is.na(mean_att) || is.na(mean_skill)) {
            warning(paste("第", i, "行：text_tea_pys 无法计算均值（可能全为 NA）"))
            return(NULL)
        }
        
        mean_att_r <- round(mean_att, 2)
        mean_skill_r <- round(mean_skill, 2)
        
        cmp_fragment <- function(m, threshold) {
            if (abs(m - threshold) < 1e-6) {
                paste0("与达标分相等（", threshold, "分）")
            } else if (m > threshold) {
                paste0("高于达标分（", threshold, "分）")
            } else {
                paste0("低于达标分（", threshold, "分）")
            }
        }
        
        frag_att <- cmp_fragment(mean_att_r, threshold_att)
        frag_skill <- cmp_fragment(mean_skill_r, threshold_skill)
        
        text <- paste0(
            "评估发现，教师心理健康态度平均分为", sprintf("%.2f", mean_att_r),
            "分，", frag_att,
            "，心理健康技能均值为", sprintf("%.2f", mean_skill_r),
            "分，", frag_skill, "。"
        )
        
        return(list(text = text))
    }, error = function(e) {
        warning(paste("第", i, "行：text_tea_pys 函数执行失败：", e$message))
        return(NULL)
    })
}

# 查看文档中所有可用样式的函数
view_doc_styles <- function(doc) {
    if (!requireNamespace("officer", quietly = TRUE)) {
        cat("需要安装 officer 包\n")
        return(NULL)
    }
    
    cat("\n========== 文档样式信息 ==========\n")
    
    # 查看段落样式
    cat("\n【段落样式】\n")
    par_styles <- officer::styles_info(doc, type = "paragraph")
    if (nrow(par_styles) > 0) {
        print(par_styles[, c("style_name", "style_id")])
    } else {
        cat("无段落样式\n")
    }
    
    # 查看表格样式
    cat("\n【表格样式】\n")
    table_styles <- officer::styles_info(doc, type = "table")
    if (nrow(table_styles) > 0) {
        print(table_styles[, c("style_name", "style_id")])
    } else {
        cat("无表格样式\n")
    }
    
    # 查看字符样式
    cat("\n【字符样式】\n")
    char_styles <- officer::styles_info(doc, type = "character")
    if (nrow(char_styles) > 0) {
        print(char_styles[, c("style_name", "style_id")])
    } else {
        cat("无字符样式\n")
    }
    
    cat("\n===================================\n\n")
    
    # 返回样式列表
    return(list(
        paragraph = par_styles,
        table = table_styles,
        character = char_styles
    ))
}

# 统一的表格样式函数
apply_table_style <- function(ft) {
    if (!requireNamespace("flextable", quietly = TRUE)) {
        return(ft)
    }
    
    # 设置表头背景色为 #B7B7B7
    ft <- flextable::bg(ft, bg = "#B7B7B7", part = "header")
    
    # 设置表头列名居中对齐
    ft <- flextable::align(ft, align = "center", part = "header")
    
    # 设置行间距为 1.2 倍（通过增加单元格内边距实现）
    # 默认 padding 约为 0.1 英寸，1.2 倍行间距需要增加上下 padding
    # 假设默认行高为 h，1.2 倍需要增加 0.2h，可以通过增加 padding 来实现
    # 这里我们设置上下 padding 为 0.12 英寸（约 1.2 倍默认值）
    # flextable::padding 使用点（points）作为单位，1 英寸 = 72 点，所以 0.12 英寸 = 8.64 点
    ft <- flextable::padding(ft, padding.top = 0.12 * 72, padding.bottom = 0.12 * 72, part = "body")
    ft <- flextable::padding(ft, padding.top = 0.12 * 72, padding.bottom = 0.12 * 72, part = "header")
    
    return(ft)
}

# 设置表格宽度和列宽自动调整
# 设置表格宽度为100%，并自动调整列宽以适应内容
set_table_width_and_autofit <- function(ft) {
    if (!requireNamespace("flextable", quietly = TRUE)) {
        return(ft)
    }
    
    # 首先使用 autofit() 自动调整列宽以适应内容
    # 这对于长文本列（如"题目"列）特别重要
    ft <- flextable::autofit(ft)
    
    # 设置表格属性：layout = "autofit" 和 width = 1 使表格宽度为100%并自动调整
    # 这会确保表格占据文档的100%宽度
    ft <- flextable::set_table_properties(ft, layout = "autofit", width = 1)
    
    return(ft)
}

# 生成各区市Score均分表格
# 输入：dat（数据），index_report_row（报告索引行），i（行号），color_palette（颜色调色板）
# 输出：data.frame对象
generate_table_score_dis <- function(dat, index_report_row, i, color_palette) {
    tryCatch({
        # 获取报告维度
        report_dim <- index_report_row$报告维度
        if (is.na(report_dim) || report_dim == "") {
            warning(paste("第", i, "行：报告维度为空"))
            return(NULL)
        }
        
        # 构建Score列名
        score_col <- paste0(report_dim, "_Score")
        
        # 检查列是否存在
        if (!score_col %in% colnames(dat)) {
            warning(paste("第", i, "行：未找到列：", score_col))
            return(NULL)
        }
        
        # 获取区市的levels（从dat中获取）
        if (!"区市" %in% colnames(dat)) {
            warning(paste("第", i, "行：数据中未找到'区市'列"))
            return(NULL)
        }
        
        # 获取区市的levels
        district_levels <- levels(dat$区市)
        if (is.null(district_levels)) {
            # 如果没有levels，获取唯一值并排序
            district_levels <- sort(unique(dat$区市))
        }
        
        # 计算每个区市的均值
        district_means <- dat %>%
            group_by(区市) %>%
            summarise(
                均值 = round(mean(!!sym(score_col), na.rm = TRUE), 1),
                .groups = 'drop'
            ) %>%
            # 确保按照levels排序
            mutate(区市 = factor(区市, levels = district_levels)) %>%
            arrange(区市)
        
        # 计算青岛市（总体）的均值
        qingdao_total <- dat %>%
            summarise(
                均值 = round(mean(!!sym(score_col), na.rm = TRUE), 1)
            )
        
        # 构建表格：青岛市在最左侧，然后按照区市的levels顺序
        # 将数据转换为宽格式：第一行是列名，第二行是数值
        table_data <- data.frame(
            青岛市 = qingdao_total$均值,
            stringsAsFactors = FALSE
        )
        
        # 添加各区市的列
        for (district in district_levels) {
            district_value <- district_means %>%
                filter(区市 == district) %>%
                pull(均值)
            if (length(district_value) > 0) {
                table_data[[district]] <- district_value
            } else {
                table_data[[district]] <- NA_real_
            }
        }
        
        # 保存表格
        table_path <- get_table_path(index_report_row)
        dir.create(table_path, showWarnings = FALSE, recursive = TRUE)
        write.csv(table_data, paste0(table_path, "/", i, "_table_score_dis.csv"), 
                  row.names = FALSE, fileEncoding = "UTF-8")
        
        return(table_data)
    }, error = function(e) {
        warning(paste("第", i, "行：generate_table_score_dis函数执行失败：", e$message))
        return(NULL)
    })
}

# 使用 doc 中的表格样式添加 flextable
# flextable::body_add_flextable() 会自动应用文档的默认表格样式
# 如果文档的默认表格样式是 "Normal Table"，直接使用即可
# 注意：flextable 对象无法直接转换为普通表格来使用特定样式，因为会丢失合并单元格等功能
# 所以这里直接使用 flextable，它会自动应用文档的默认表格样式
# 为纵向合并单元格所在行设置上下黑色边框
# 通过检查哪些列有连续相同的值来确定合并的行
set_merged_cell_borders <- function(ft, table_data, merged_cols = NULL) {
    if (!requireNamespace("flextable", quietly = TRUE)) {
        return(ft)
    }
    
    # 获取表格的行数和列数
    n_rows <- nrow(table_data)
    n_cols <- ncol(table_data)
    
    if (n_rows == 0 || n_cols == 0) {
        return(ft)
    }
    
    # 如果没有指定合并的列，尝试自动检测（查找可能合并的列：分类、类别、指标等）
    if (is.null(merged_cols)) {
        merged_cols <- grep("^(分类|类别|指标|变化趋势|测量内容|变量类型|评估工具|学期|专业)(\\.1)?$", 
                           colnames(table_data), value = FALSE)
    }
    
    # 找出有纵向合并的行范围（这些行在合并列中有连续相同的值）
    merged_row_ranges <- list()
    
    for (col_idx in merged_cols) {
        if (col_idx <= ncol(table_data)) {
            col_data <- table_data[[col_idx]]
            current_value <- NULL
            start_row <- 1
            
            for (r in seq_len(n_rows)) {
                cell_value <- as.character(col_data[r])
                if (is.na(cell_value)) cell_value <- ""
                
                if (is.null(current_value)) {
                    current_value <- cell_value
                } else if (cell_value != current_value) {
                    # 如果当前行与上一行不同，且上一批有多行，则记录合并范围
                    if (r > start_row + 1) {
                        # 记录合并范围：start_row 到 r-1
                        merged_row_ranges[[length(merged_row_ranges) + 1]] <- c(start_row, r - 1)
                    }
                    current_value <- cell_value
                    start_row <- r
                }
            }
            
            # 处理最后一批
            if (n_rows > start_row + 1) {
                merged_row_ranges[[length(merged_row_ranges) + 1]] <- c(start_row, n_rows)
            }
        }
    }
    
    # 为每个合并范围设置边框
    if (length(merged_row_ranges) > 0) {
        for (range in merged_row_ranges) {
            start_row <- range[1]
            end_row <- range[2]
            
            # 为合并范围的顶部行设置顶部边框（如果不是第一行）
            if (start_row > 1) {
                ft <- ft %>% flextable::border(i = start_row, j = seq_len(n_cols), 
                                               border.top = officer::fp_border(color = "black", width = 1),
                                               part = "body")
            }
            
            # 为合并范围的底部行设置底部边框（如果不是最后一行）
            if (end_row < n_rows) {
                ft <- ft %>% flextable::border(i = end_row, j = seq_len(n_cols), 
                                               border.bottom = officer::fp_border(color = "black", width = 1),
                                               part = "body")
            }
        }
    }
    
    return(ft)
}

add_table_to_doc <- function(doc, ft, table_style = NULL, use_autofit = TRUE) {
    if (!requireNamespace("flextable", quietly = TRUE)) {
        stop("需要 flextable 包")
    }
    if (!requireNamespace("officer", quietly = TRUE)) {
        stop("需要 officer 包")
    }
    
    # 设置表格宽度为100%并自动调整列宽
    # 性能优化：对于大表格，可以跳过autofit（如果表格列数很多或行数很多）
    if (use_autofit) {
        ft <- set_table_width_and_autofit(ft)
    } else {
        # 只设置表格属性，不进行autofit（更快），但仍需设置width = 1
        ft <- flextable::set_table_properties(ft, layout = "autofit", width = 1)
    }
    
    # 设置表头（所有列名）居中对齐
    ft <- ft %>% flextable::align(align = "center", part = "header")
    
    # 直接使用 flextable（会自动应用文档的默认表格样式）
    # 如果文档的默认表格样式是 "Normal Table"，这里就会自动使用该样式
    # table_style 参数保留用于兼容性，但实际不使用（因为 flextable 会自动应用默认样式）
    doc <- doc %>% flextable::body_add_flextable(ft)
    # 在表格后添加一个空行
    doc <- doc %>% officer::body_add_par("")
    return(doc)
}

# 报告写入函数
write_report_to_doc <- function(doc, index_report, chart_objects, date_str, failed_charts = NULL) {
    cat("开始写入报告，图表对象数量：", length(chart_objects), "\n")
    
    # 如果没有传入failed_charts，创建一个新的
    # 性能优化：使用list而不是data.frame，最后一次性转换为data.frame
    if (is.null(failed_charts)) {
        failed_charts <- list(
            行号 = integer(),
            图表类型 = character(),
            报告维度 = character(),
            失败原因 = character()
        )
    } else {
        # 如果传入的是data.frame，转换为list格式以便高效追加
        if (is.data.frame(failed_charts)) {
            failed_charts <- list(
                行号 = failed_charts$行号,
                图表类型 = failed_charts$图表类型,
                报告维度 = failed_charts$报告维度,
                失败原因 = failed_charts$失败原因
            )
        }
    }
    
    # 添加目录（包含前4级标题）
    if (requireNamespace("officer", quietly = TRUE)) {
        tryCatch({
            # # 先添加一个空段落，确保文档有内容
            # doc <- doc %>% officer::body_add_par("")
            # 添加目录字段（level参数指定包含到第几级，4表示包含1-4级标题）
            doc <- doc %>% officer::body_add_toc(level = 3)
            cat("已添加目录（包含1-4级标题）\n")
        }, error = function(e) {
            warning(paste("添加目录失败：", e$message))
        })
    }
    
    # 添加分页符
    if (requireNamespace("officer", quietly = TRUE)) {
        doc <- doc %>% officer::body_add_break()
        cat("已添加分页符\n")
    }
    
    # 遍历index_report的每一行
    written_rows <- 0
    for (i in seq_len(nrow(index_report))) {
        row <- index_report[i, ]
        
        # 检查是否有效：值为1、TRUE、"1"、"是"等表示有效
        if ("是否有效" %in% colnames(index_report)) {
            valid_value <- row$是否有效
            # 转换为统一格式进行比较
            if (is.na(valid_value)) {
                next  # NA视为无效
            } else if (is.logical(valid_value)) {
                if (!valid_value) {
                    next  # FALSE视为无效
                }
            } else if (is.numeric(valid_value)) {
                if (valid_value != 1) {
                    next  # 只有1才有效
                }
            } else {
                valid_str <- as.character(valid_value)
                if (!valid_str %in% c("1", "是", "TRUE", "True", "true")) {
                    next  # 只有这些值才有效
                }
            }
        }
        
        written_rows <- written_rows + 1
        
        # 写入一级标题
        if (!is.na(row$一级标题) && row$一级标题 != "") {
            doc <- doc %>% body_add_par(row$一级标题, style = "heading 1")
            cat("第", i, "行：写入一级标题\n")
        }
        
        # 写入二级标题
        if (!is.na(row$二级标题) && row$二级标题 != "") {
            doc <- doc %>% body_add_par(row$二级标题, style = "heading 2")
        }
        
        # 写入三级标题
        if (!is.na(row$三级标题) && row$三级标题 != "") {
            doc <- doc %>% body_add_par(row$三级标题, style = "heading 3")
        }
        
        # 写入四级标题
        if (!is.na(row$四级标题) && row$四级标题 != "") {
            doc <- doc %>% body_add_par(row$四级标题, style = "heading 4")
        }
        
        # 写入五级标题
        if (!is.na(row$五级标题) && row$五级标题 != "") {
            doc <- doc %>% body_add_par(row$五级标题, style = "heading 5")
        }
        
        # 写入文本段落
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
        
        # 写入线下图表
        if (!is.na(row$线下图表) && row$线下图表 != "") {
            if (row$报告学段 == "高中") {
                file_path <- file.path("9 pics and tables/1 h", row$线下图表)
            } else if (row$报告学段 == "中职") {
                file_path <- file.path("9 pics and tables/2 c", row$线下图表)
            } else if (row$报告学段 == "初中") {
                file_path <- file.path("9 pics and tables/3 jh", row$线下图表)
            } else {
                warning(paste("第", i, "行：报告学段为空或未知，跳过线下图表"))
                next  # 跳过这一行，继续处理下一行，而不是返回NULL
            }
            if (file.exists(file_path)) {
                # 获取文件扩展名
                file_ext <- tolower(tools::file_ext(file_path))
                
                if (file_ext == "png") {
                    # 图片文件：读取图片尺寸，计算高度以保持原始比例
                    # 性能优化：对于大图片，直接使用默认尺寸以避免读取完整像素数据
                    tryCatch({
                        # 检查文件大小，如果太大（>5MB），直接使用默认尺寸
                        file_size_mb <- file.info(file_path)$size / (1024 * 1024)
                        if (file_size_mb > 5) {
                            # 大文件：使用默认尺寸，不读取像素数据
                            doc <- doc %>% body_add_img(file_path, width = 6, height = 4.5)
                            doc <- doc %>% officer::body_add_par("")  # 图片后添加空行
                            cat("第", i, "行：写入线下图片", file_path, "（大文件，使用默认尺寸）\n")
                        } else {
                            # 小文件：读取尺寸信息
                            img_array <- png::readPNG(file_path, native = TRUE)
                            img_dims <- dim(img_array)
                            
                            if (is.null(img_dims) || length(img_dims) < 2) {
                                stop("无法获取图片尺寸信息")
                            }
                            
                            img_height_px <- img_dims[1]  # 高度（像素）
                            img_width_px <- img_dims[2]   # 宽度（像素）
                            
                            # 计算宽高比
                            aspect_ratio <- img_height_px / img_width_px
                            
                            # 设置宽度为页面内容区域宽度（6英寸）
                            page_width <- 6
                            page_height <- page_width * aspect_ratio
                            
                            doc <- doc %>% body_add_img(file_path, width = page_width, height = page_height)
                            doc <- doc %>% officer::body_add_par("")  # 图片后添加空行
                            cat("第", i, "行：写入线下图片", file_path, "\n")
                        }
                    }, error = function(e) {
                        # 如果读取失败，使用默认尺寸
                        warning(paste("第", i, "行：读取图片尺寸失败，使用默认尺寸：", e$message))
                        doc <<- doc %>% body_add_img(file_path, width = 6, height = 4.5)
                        doc <<- doc %>% officer::body_add_par("")  # 图片后添加空行
                        cat("第", i, "行：写入线下图片", file_path, "（使用默认尺寸）\n")
                    })
                } else if (file_ext %in% c("xlsx", "csv")) {
                    # 表格文件：读取并处理
                    tryCatch({
                        # 读取表格
                        if (file_ext == "xlsx") {
                            table_data <- openxlsx::read.xlsx(file_path)
            } else {
                            table_data <- read.csv(file_path, fileEncoding = "UTF-8", stringsAsFactors = FALSE)
                        }
                        
                        # 添加表名（如果存在）
                        if ("图题表题" %in% colnames(row) && !is.na(row$图题表题) && row$图题表题 != "") {
                            doc <- doc %>% officer::body_add_par(row$图题表题, style = "图表标题")
                        }
                        
                        # 保存原始列名（用于后续处理）
                        original_colnames <- colnames(table_data)
                        
                        # 使用flextable处理表格
                        if (requireNamespace("flextable", quietly = TRUE)) {
                            # 保持原始列名创建flextable（避免重复列名错误）
                            ft <- flextable::flextable(table_data)
                            
                            # 列名为"分类"或"分类.1"的列纵向合并单元格
                            classification_cols <- grep("^分类(\\.1)?$", colnames(table_data), value = FALSE)
                            for (classification_col_idx in classification_cols) {
                                if (!is.na(classification_col_idx) && nrow(table_data) > 1) {
                                    classification_col_name <- colnames(table_data)[classification_col_idx]
                                    current_classification <- ""
                                    start_row_class <- 1
                                    
                                    for (r in seq_len(nrow(table_data))) {
                                        cell_value <- as.character(table_data[[classification_col_name]][r])
                                        if (is.na(cell_value)) cell_value <- ""
                                        
                                        if (cell_value != current_classification) {
                                            if (current_classification != "" && r > start_row_class) {
                                                # 只有多行相同值时才合并
                                                ft <- flextable::merge_at(ft, i = start_row_class:(r-1), j = classification_col_idx)
                                            }
                                            current_classification <- cell_value
                                            start_row_class <- r
                                        }
                                    }
                                    # 合并最后一批（只有多行相同值时才合并）
                                    if (start_row_class < nrow(table_data)) {
                                        ft <- flextable::merge_at(ft, i = start_row_class:nrow(table_data), j = classification_col_idx)
                                    }
                                }
                            }
                            
                            # 列名为"类别"、"指标"或"变化趋势"（可能带".1"后缀）的列纵向合并单元格
                            # 匹配包含这些关键词的列名（不仅仅是开头）
                            category_cols <- grep("(分类|类别|指标|维度|变化趋势|测量内容|学期|专业)(\\.1)?$", colnames(table_data), value = FALSE)
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
                                    new_name <- gsub("\\.1$", "", col_name)
                                    header_labels[[col_name]] <- new_name
                                }
                            }
                            ft <- flextable::set_header_labels(ft, values = header_labels)
                            
                            # 为纵向合并单元格所在行设置上下黑色边框
                            merged_cols <- c(classification_cols, category_cols)
                            if (length(merged_cols) > 0) {
                                ft <- set_merged_cell_borders(ft, table_data, merged_cols = merged_cols)
                            }
                            
                            # 写入表格（性能优化：对于大表格跳过autofit）
                            use_autofit <- nrow(table_data) < 100 && ncol(table_data) < 15
                            doc <- add_table_to_doc(doc, ft, table_style = "Normal Table", use_autofit = use_autofit)
                            cat("第", i, "行：写入线下表格", file_path, "\n")
                        } else {
                            # 如果没有flextable，使用普通表格（需要去掉列名中的".1"后缀）
                            colnames(table_data) <- gsub("\\.1$", "", colnames(table_data))
                            doc <- doc %>% body_add_table(table_data, style = "Normal Table")
                            doc <- doc %>% officer::body_add_par("")  # 表格后添加空行
                            cat("第", i, "行：写入线下表格", file_path, "（注意：需要flextable包才能合并单元格）\n")
                        }
                    }, error = function(e) {
                        warning(paste("第", i, "行：读取线下表格失败", file_path, "：", e$message))
                    })
                } else {
                    warning(paste("第", i, "行：不支持的文件格式", file_ext, "，文件：", file_path))
                }
            } else {
                warning(paste("第", i, "行：未找到文件", file_path))
            }
        }
        
        # 写入生成的图表
        if (!is.na(row$图表类型) && row$图表类型 != "") {
            # achievement_doc_generate类型：读取已保存的文档并添加到主文档
            if (row$图表类型 == "achievement_doc_generate") {
                # sub_name <- ifelse(is.na(row$报告维度), "", as.character(row$报告维度))
                # if (sub_name == "") {
                #     warning(paste("第", i, "行：achievement_doc_generate类型但报告维度为空，跳过"))
                # } else {
                #     doc_file <- paste0("10 过程报告/3 jh/temp_reprot_for_academic_", sub_name, ".docx")
                    
                #     # 检查文件是否存在
                #     if (!file.exists(doc_file)) {
                #         warning(paste("第", i, "行：未找到学业报告文件", doc_file, "，跳过添加"))
                #         failed_charts <<- rbind(failed_charts, data.frame(
                #             行号 = i,
                #             图表类型 = as.character(row$图表类型),
                #             报告维度 = sub_name,
                #             失败原因 = paste("文件不存在：", doc_file),
                #             stringsAsFactors = FALSE
                #         ))
                #     } else {
                #         # 验证文件大小
                #         file_size <- file.info(doc_file)$size
                #         if (file_size == 0) {
                #             warning(paste("第", i, "行：学业报告文件为空", doc_file, "，跳过添加"))
                #             failed_charts <<- rbind(failed_charts, data.frame(
                #                 行号 = i,
                #                 图表类型 = as.character(row$图表类型),
                #                 报告维度 = sub_name,
                #                 失败原因 = paste("文件为空：", doc_file),
                #                 stringsAsFactors = FALSE
                #             ))
                #         } else {
                #             # 尝试添加文档
                #             tryCatch({
                #                 # 先验证子文档是否可以正常读取
                #                 test_doc <- tryCatch({
                #                     read_docx(doc_file)
                #                 }, error = function(e) {
                #                     stop(paste("无法读取子文档：", e$message))
                #                 })
                                
                #                 # 在合并前添加分页符，确保内容分离
                #                 doc <- doc %>% body_add_break(pos = "after")
                                
                #                 # 使用 body_add_docx 合并文档
                #                 # 注意：body_add_docx 依赖 Microsoft Word 的特性，在非 Word 软件中可能无法正常工作
                #                 # 为了确保文档格式正确，我们在合并后立即保存并重新读取
                #                 doc <- doc %>% body_add_docx(src = doc_file, pos = "after")
                                
                #                 # 合并后立即保存到临时文件并重新读取，确保格式正确
                #                 # 这样可以修复可能的格式问题
                #                 temp_merged_doc <- tempfile(fileext = ".docx")
                #                 tryCatch({
                #                     print(doc, target = temp_merged_doc)
                #                     # 验证文件是否成功创建
                #                     if (!file.exists(temp_merged_doc) || file.info(temp_merged_doc)$size == 0) {
                #                         stop("合并后文档保存失败或文件为空")
                #                     }
                #                     # 重新读取文档
                #                     doc <- read_docx(temp_merged_doc)
                #                     # 清理临时文件
                #                     unlink(temp_merged_doc)
                #                 }, error = function(e) {
                #                     # 如果保存/读取失败，清理临时文件并抛出错误
                #                     if (file.exists(temp_merged_doc)) {
                #                         unlink(temp_merged_doc)
                #                     }
                #                     stop(paste("合并后文档保存/读取失败：", e$message))
                #                 })
                                
                #                 # 合并后再添加一个分页符，确保后续内容分离
                #                 doc <- doc %>% body_add_break(pos = "after")
                                
                #                 cat("第", i, "行：成功添加", sub_name, "学科报告\n")
                #             }, error = function(e) {
                #                 warning(paste("第", i, "行：添加学业报告失败：", e$message))
                #                 failed_charts <<- rbind(failed_charts, data.frame(
                #                     行号 = i,
                #                     图表类型 = as.character(row$图表类型),
                #                     报告维度 = sub_name,
                #                     失败原因 = paste("添加文档失败：", e$message),
                #                     stringsAsFactors = FALSE
                #                 ))
                #             })
                #         }
                #     }
                # }
                # 跳过后续的图表处理逻辑
                next
            }
            chart_obj_name <- paste0("chart_", i)
            if (chart_obj_name %in% names(chart_objects)) {
                chart_obj <- chart_objects[[chart_obj_name]]
                
                # 如果是表格，添加标题
                if (is.data.frame(chart_obj) || (!is.null(chart_obj$table) && is.null(chart_obj$plot))) {
                    # 添加表格（使用模板中实际存在的样式）
                    tryCatch({
                        # 获取表格数据（支持多个表格）
                        tables_to_add <- list()
                        if (is.data.frame(chart_obj)) {
                            tables_to_add <- list(chart_obj)
                        } else if (!is.null(chart_obj$tables) && is.list(chart_obj$tables)) {
                            # 多个表格的情况
                            tables_to_add <- chart_obj$tables
                        } else if (!is.null(chart_obj$table)) {
                            tables_to_add <- list(chart_obj$table)
                        }
                        
                        # 如果是ANOVA_scores且有事后检验表格，添加事后检验表格
                        if (row$图表类型 == "ANOVA_scores" && !is.null(chart_obj$posthoc_table)) {
                            tables_to_add <- c(tables_to_add, list(chart_obj$posthoc_table))
                        }
                        
                        # 检查是否有表格数据
                        if (length(tables_to_add) == 0) {
                            warning(paste("第", i, "行：没有表格数据，无法写入表格"))
                            # 记录失败（性能优化：使用list追加而不是rbind）
                            failed_charts$行号 <<- c(failed_charts$行号, i)
                            failed_charts$图表类型 <<- c(failed_charts$图表类型, ifelse(is.na(row$图表类型), "", as.character(row$图表类型)))
                            failed_charts$报告维度 <<- c(failed_charts$报告维度, ifelse(is.na(row$报告维度), "", as.character(row$报告维度)))
                            failed_charts$失败原因 <<- c(failed_charts$失败原因, "没有表格数据")
                            # 跳过后续处理，但不返回函数（使用stop来跳出tryCatch）
                            stop("没有表格数据")
                        }
                        
                        # 处理每个表格
                        for (table_idx in seq_along(tables_to_add)) {
                            table_to_add <- tables_to_add[[table_idx]]
                            
                            # 检查table_to_add是否为空
                            if (is.null(table_to_add) || nrow(table_to_add) == 0) {
                                next
                            }
                            
                            # 检查是否是事后检验表格（通过列名判断）
                            is_posthoc_table <- "对比类别1" %in% colnames(table_to_add)
                            
                            # 添加表格标题
                            if (is_posthoc_table) {
                                # 事后检验表格：使用原表名+（事后检验结果）
                                original_title <- ifelse(is.na(row$图题表题) || row$图题表题 == "", "", row$图题表题)
                                posthoc_title <- paste0(original_title, "（事后检验结果）")
                                if (posthoc_title != "（事后检验结果）") {
                                    doc <- doc %>% body_add_par(posthoc_title, style = "图表标题")
                                }
                            } else if (table_idx == 1) {
                                # 第一个表格（非事后检验）：使用原表名
                                if (!is.na(row$图题表题) && row$图题表题 != "") {
                                    doc <- doc %>% body_add_par(row$图题表题, style = "图表标题")
                                }
                            }
                        
                        # 如果是table_figures，需要将值*100后根据figures_with_dot决定小数位数
                        if (row$图表类型 == "table_figures" && !is.null(table_to_add)) {
                            # table_figures已经转置，列名是指标名称
                            # 获取报告维度，检查是否在figures_with_dot中
                            dims_str <- row$报告维度
                            if (!is.na(dims_str) && dims_str != "") {
                                dims <- strsplit(dims_str, "、", fixed = TRUE)[[1]]
                                dims <- trimws(dims)
                                
                                # 从全局环境获取figures_with_dot（如果存在）
                                if (exists("figures_with_dot", envir = .GlobalEnv)) {
                                    figures_with_dot <- get("figures_with_dot", envir = .GlobalEnv)
                                } else {
                                    figures_with_dot <- c()
                                }
                                
                                # 对每个指标列进行格式化
                                for (col_name in colnames(table_to_add)) {
                                    if (is.numeric(table_to_add[[col_name]])) {
                                        # 检查该指标是否在figures_with_dot中
                                        use_decimal <- col_name %in% figures_with_dot
                                        decimal_digits <- ifelse(use_decimal, 1, 0)
                                        # 将值*100后根据小数位数格式化（使用suppressWarnings避免类型转换警告）
                                        table_to_add[[col_name]] <- suppressWarnings(round(table_to_add[[col_name]] * 100, decimal_digits))
                                    }
                                }
                            } else {
                                # 如果没有报告维度信息，默认保留整数
                                for (col_name in colnames(table_to_add)) {
                                    if (is.numeric(table_to_add[[col_name]])) {
                                        table_to_add[[col_name]] <- suppressWarnings(round(table_to_add[[col_name]] * 100, 0))
                                    }
                                }
                            }
                        }
                        
                        # 如果是table_dims_score/table_dims_figure/table_dims_figures_percent/table_dims_figures，需要根据类型和小数位数格式化
                        if ((row$图表类型 == "table_dims_score" || row$图表类型 == "table_dims_figure" || row$图表类型 == "table_dims_figures_percent" || row$图表类型 == "table_dims_figures") && !is.null(table_to_add)) {
                            # table_dims_score已经转置，列名是指标名称
                            chart_type <- row$图表类型
                            is_score_type <- chart_type == "table_dims_score"
                            is_percent_type <- chart_type == "table_dims_figures_percent"
                            is_figures_type <- chart_type == "table_dims_figures"
                            
                            # 获取报告维度，检查是否在figures_with_dot中
                            dims_str <- row$报告维度
                            if (!is.na(dims_str) && dims_str != "") {
                                dims <- strsplit(dims_str, "、", fixed = TRUE)[[1]]
                                dims <- trimws(dims)
                                
                                # 从全局环境获取figures_with_dot（如果存在）
                                if (exists("figures_with_dot", envir = .GlobalEnv)) {
                                    figures_with_dot <- get("figures_with_dot", envir = .GlobalEnv)
                                } else {
                                    figures_with_dot <- c()
                                }
                                
                                # 对每个指标列进行格式化
                                for (col_name in colnames(table_to_add)) {
                                    # 检查列是否是数值型（排除已经是字符型的列，如包含%的列）
                                    if (is.numeric(table_to_add[[col_name]])) {
                                        if (is_score_type) {
                                            # Score类型：保留1位小数
                                            decimal_digits <- 1
                                            # 不乘以100
                                            table_to_add[[col_name]] <- suppressWarnings(round(table_to_add[[col_name]], decimal_digits))
                                        } else if (is_percent_type) {
                                            # table_dims_figures_percent类型：检查该指标是否在figures_with_dot中，然后乘以100
                                            # 注意：如果generate_table_dims_score已经将值转换为带%的字符串，这里应该跳过
                                            if (is.character(table_to_add[[col_name]]) && any(grepl("%", table_to_add[[col_name]], fixed = TRUE))) {
                                                # 已经是带%的字符串，跳过处理
                                                next
                                            }
                                            use_decimal <- col_name %in% figures_with_dot
                                            decimal_digits <- ifelse(use_decimal, 1, 0)
                                            # 确保值是数值型后再进行运算
                                            if (is.numeric(table_to_add[[col_name]])) {
                                                # 确保没有NA值导致警告
                                                table_to_add[[col_name]] <- suppressWarnings(round(table_to_add[[col_name]] * 100, decimal_digits))
                                            }
                                        } else {
                                            # table_dims_figure和table_dims_figures类型：乘以100并round成整数
                                            # 确保值是数值型后再进行运算
                                            if (is.numeric(table_to_add[[col_name]])) {
                                                table_to_add[[col_name]] <- suppressWarnings(round(table_to_add[[col_name]] * 100, 0))
                                            }
                                        }
                                    } else if (is.character(table_to_add[[col_name]]) && is_percent_type) {
                                        # 如果列已经是字符型且包含%，说明已经在generate_table_dims_score中格式化过了
                                        # 不需要再次处理，跳过
                                        next
                                    }
                                }
                            } else {
                                # 如果没有报告维度信息，根据类型决定小数位数
                                for (col_name in colnames(table_to_add)) {
                                    # 检查列是否是数值型（排除已经是字符型的列）
                                    if (is.numeric(table_to_add[[col_name]])) {
                                        if (is_score_type) {
                                            table_to_add[[col_name]] <- suppressWarnings(round(table_to_add[[col_name]], 1))
                                        } else if (is_percent_type) {
                                            # 注意：如果generate_table_dims_score已经将值转换为带%的字符串，这里应该跳过
                                            if (is.character(table_to_add[[col_name]]) && any(grepl("%", table_to_add[[col_name]], fixed = TRUE))) {
                                                # 已经是带%的字符串，跳过处理
                                                next
                                            }
                                            # 确保值是数值型后再进行运算
                                            if (is.numeric(table_to_add[[col_name]])) {
                                                # 确保没有NA值导致警告
                                                table_to_add[[col_name]] <- suppressWarnings(round(table_to_add[[col_name]] * 100, 0))
                                            }
                                        } else {
                                            # table_dims_figure和table_dims_figures类型：乘以100并round成整数
                                            # 确保值是数值型后再进行运算
                                            if (is.numeric(table_to_add[[col_name]])) {
                                                # 确保没有NA值导致警告
                                                table_to_add[[col_name]] <- suppressWarnings(round(table_to_add[[col_name]] * 100, 0))
                                            }
                                        }
                                    } else if (is.character(table_to_add[[col_name]]) && is_percent_type) {
                                        # 如果列已经是字符型且包含%，说明已经在generate_table_dims_score中格式化过了
                                        # 不需要再次处理，跳过
                                        next
                                    }
                                }
                            }
                        }
                        
                        # 如果是linear_regression，需要将NA替换为空字符串
                        if (row$图表类型 == "linear_regression" && !is.null(table_to_add)) {
                            # 将所有NA值替换为空字符串
                            table_to_add[is.na(table_to_add)] <- ""
                        }
                        
                        # 如果是Cronbach_alpha，确保题目数量显示为整数
                        if (row$图表类型 == "Cronbach_alpha" && !is.null(table_to_add) && "参数" %in% colnames(table_to_add)) {
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
                        if (row$图表类型 == "table_items_score" && !is.null(table_to_add) && "题目" %in% colnames(table_to_add) && "平均分" %in% colnames(table_to_add)) {
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
                        
                        # 如果是ANOVA_scores，需要将变量名替换为中文名称
                        if (row$图表类型 == "ANOVA_scores" && !is.null(table_to_add) && "分组变量" %in% colnames(table_to_add)) {
                            # 变量名对应表
                            var_name_mapping <- c(
                                "Gen" = "性别",
                                "Loc" = "城乡",
                                "Fam" = "家庭结构",
                                "Sim" = "子女数量",  # 兼容Sim和Sib
                                "Edu_m" = "母亲学历",
                                "Edu_f" = "父亲学历",
                                "SES" = "家庭教育投入"
                            )
                            # 替换分组变量列中的变量名
                            for (var_code in names(var_name_mapping)) {
                                table_to_add$分组变量[table_to_add$分组变量 == var_code] <- var_name_mapping[var_code]
                            }
                        }
                        
                        # 如果是table_basic_infor_figures，需要处理合并单元格
                        if (row$图表类型 == "table_basic_infor_figures") {
                            # 调试信息
                            cat("第", i, "行：处理table_basic_infor_figures，table_to_add是否为NULL：", is.null(table_to_add), "\n")
                            if (!is.null(table_to_add)) {
                                cat("第", i, "行：table_to_add的列名：", paste(colnames(table_to_add), collapse = ", "), "\n")
                                cat("第", i, "行：table_to_add的行数：", nrow(table_to_add), "\n")
                            }
                            
                            if (!is.null(table_to_add) && "分类" %in% colnames(table_to_add)) {
                                # 检查指标数量（除了"分类"和"类别"列之外的列数）
                                indicator_cols <- setdiff(colnames(table_to_add), c("分类", "类别"))
                                n_indicators <- length(indicator_cols)
                                
                                    # 如果行数为3或4，转换成左右两列格式
                                    if (nrow(table_to_add) == 3 || nrow(table_to_add) == 4) {
                                        # 定义左侧和右侧的分类
                                        left_categories <- c("性别", "城乡", "家庭结构")
                                        right_categories <- c("母亲学历", "父亲学历", "家庭教育投入")
                                        
                                        # 分离左侧和右侧数据
                                        left_data <- table_to_add[table_to_add$分类 %in% left_categories, ]
                                        right_data <- table_to_add[table_to_add$分类 %in% right_categories, ]
                                        
                                        # 确定最大行数（用于对齐）
                                        max_rows <- max(nrow(left_data), nrow(right_data))
                                        
                                        # 创建左右并排的表格（列名：分类、类别、指标...、分类、类别、指标...）
                                        combined_table <- data.frame(
                                            分类 = character(max_rows),
                                            类别 = character(max_rows),
                                            stringsAsFactors = FALSE,
                                            check.names = FALSE
                                        )
                                        
                                        # 添加指标列（左侧）
                                        for (ind in indicator_cols) {
                                            combined_table[[ind]] <- numeric(max_rows)
                                        }
                                        
                                        # 添加右侧列（分类、类别、指标）
                                        combined_table$分类.1 <- character(max_rows)
                                        combined_table$类别.1 <- character(max_rows)
                                        for (ind in indicator_cols) {
                                            combined_table[[paste0(ind, ".1")]] <- numeric(max_rows)
                                        }
                                        
                                        # 填充左侧数据
                                        for (r in seq_len(nrow(left_data))) {
                                            combined_table$分类[r] <- left_data$分类[r]
                                            combined_table$类别[r] <- left_data$类别[r]
                                            for (ind in indicator_cols) {
                                                combined_table[[ind]][r] <- left_data[[ind]][r]
                                            }
                                        }
                                        
                                        # 填充右侧数据
                                        for (r in seq_len(nrow(right_data))) {
                                            combined_table$分类.1[r] <- right_data$分类[r]
                                            combined_table$类别.1[r] <- right_data$类别[r]
                                            for (ind in indicator_cols) {
                                                combined_table[[paste0(ind, ".1")]][r] <- right_data[[ind]][r]
                                            }
                                        }
                                        
                                        # 将NA替换为空字符串
                                        combined_table[is.na(combined_table)] <- ""
                                        
                                        table_to_add <- combined_table
                                        
                                        # 使用flextable处理
                                        if (requireNamespace("flextable", quietly = TRUE)) {
                                            ft <- flextable::flextable(table_to_add)
                                            
                                            # 修改表头显示：将右侧的"分类.1"、"类别.1"、"指标.1"改为"分类"、"类别"、"指标"
                                            header_labels_list <- as.list(colnames(table_to_add))
                                            names(header_labels_list) <- colnames(table_to_add)
                                            for (ind in indicator_cols) {
                                                if (paste0(ind, ".1") %in% names(header_labels_list)) {
                                                    header_labels_list[[paste0(ind, ".1")]] <- ind
                                                }
                                            }
                                            if ("分类.1" %in% names(header_labels_list)) {
                                                header_labels_list[["分类.1"]] <- "分类"
                                            }
                                            if ("类别.1" %in% names(header_labels_list)) {
                                                header_labels_list[["类别.1"]] <- "类别"
                                            }
                                            ft <- flextable::set_header_labels(ft, values = header_labels_list)
                                            
                                            # 合并左侧相同分类的单元格（第1列：分类）
                                            current_class_left <- ""
                                            start_row_left <- 1
                                            left_group_end_rows <- c()  # 记录左侧每个分类组的结束行
                                            for (r in 1:max_rows) {
                                                if (combined_table$分类[r] != "" && combined_table$分类[r] != current_class_left) {
                                                    if (current_class_left != "" && r > start_row_left) {
                                                        ft <- flextable::merge_at(ft, i = start_row_left:(r-1), j = 1)
                                                        left_group_end_rows <- c(left_group_end_rows, r - 1)
                                                    }
                                                    current_class_left <- combined_table$分类[r]
                                                    start_row_left <- r
                                                }
                                            }
                                            # 合并最后一批左侧分类
                                            if (current_class_left != "" && start_row_left <= max_rows) {
                                                end_row <- start_row_left
                                                for (r in start_row_left:max_rows) {
                                                    if (combined_table$分类[r] == current_class_left) {
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
                                            # 计算右侧分类列的索引：左侧列数（分类+类别+指标列数）+ 1
                                            right_class_col <- 1 + length(indicator_cols) + 2
                                            current_class_right <- ""
                                            start_row_right <- 1
                                            right_group_end_rows <- c()  # 记录右侧每个分类组的结束行
                                            for (r in 1:max_rows) {
                                                if (combined_table$分类.1[r] != "" && combined_table$分类.1[r] != current_class_right) {
                                                    if (current_class_right != "" && r > start_row_right) {
                                                        ft <- flextable::merge_at(ft, i = start_row_right:(r-1), j = right_class_col)
                                                        right_group_end_rows <- c(right_group_end_rows, r - 1)
                                                    }
                                                    current_class_right <- combined_table$分类.1[r]
                                                    start_row_right <- r
                                                }
                                            }
                                            # 合并最后一批右侧分类
                                            if (current_class_right != "" && start_row_right <= max_rows) {
                                                end_row <- start_row_right
                                                for (r in start_row_right:max_rows) {
                                                    if (combined_table$分类.1[r] == current_class_right) {
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
                                            
                                            # 为左侧和右侧每个分类组的最后一行添加底部边框（横线）
                                            all_group_end_rows <- unique(c(left_group_end_rows, right_group_end_rows))
                                            if (length(all_group_end_rows) > 0) {
                                                for (end_row in all_group_end_rows) {
                                                    if (end_row < max_rows) {
                                                        n_cols <- length(colnames(combined_table))
                                                        ft <- flextable::border(ft, 
                                                                               i = end_row, 
                                                                               j = seq_len(n_cols),
                                                                               border.bottom = officer::fp_border(color = "black", width = 1),
                                                                               part = "body")
                                                    }
                                                }
                                            }
                                            
                                            # 不应用自定义样式，使用 doc 的 "Normal Table" 样式
                                            # ft <- apply_table_style(ft)
                                            
                                            # 使用 doc 的 "Normal Table" 样式添加表格（性能优化：对于大表格跳过autofit）
                                            use_autofit <- nrow(table_to_add) < 100 && ncol(table_to_add) < 15
                                            doc <- add_table_to_doc(doc, ft, table_style = "Normal Table", use_autofit = use_autofit)
                                            cat("第", i, "行：写入表格", table_idx, "（左右两列格式，样式：Normal Table）\n")
                                        } else {
                                            # 如果没有flextable，使用普通表格并应用 "Normal Table" 样式
                                            tryCatch({
                                                doc <- doc %>% body_add_table(table_to_add, style = "Normal Table")
                                                cat("第", i, "行：写入表格", table_idx, "（左右两列格式，样式：Normal Table，注意：需要flextable包才能应用统一样式）\n")
                                            }, error = function(e) {
                                                # 如果样式失败，使用默认方式
                                                doc <<- doc %>% body_add_table(table_to_add)
                                                cat("第", i, "行：写入表格", table_idx, "（左右两列格式，默认样式，注意：需要flextable包才能应用统一样式）\n")
                                            })
                                        }
                                    } else {
                                        # 多个指标时，使用原来的纵向合并单元格逻辑
                                        if (requireNamespace("flextable", quietly = TRUE)) {
                                            ft <- flextable::flextable(table_to_add)
                                            # 合并相同分类的单元格，并记录每个组的结束行
                                            current_class <- ""
                                            start_row <- 1
                                            group_end_rows <- c()  # 记录每个分类组的结束行
                                            for (r in seq_len(nrow(table_to_add))) {
                                                if (table_to_add$分类[r] != current_class) {
                                                    if (current_class != "" && r > start_row) {
                                                        ft <- flextable::merge_at(ft, i = start_row:(r-1), j = 1)
                                                        group_end_rows <- c(group_end_rows, r - 1)
                                                    }
                                                    current_class <- table_to_add$分类[r]
                                                    start_row <- r
                                                }
                                            }
                                            # 合并最后一批
                                            if (start_row <= nrow(table_to_add)) {
                                                ft <- flextable::merge_at(ft, i = start_row:nrow(table_to_add), j = 1)
                                                if (start_row <= nrow(table_to_add) - 1) {
                                                    group_end_rows <- c(group_end_rows, nrow(table_to_add))
                                                }
                                            }
                                            
                                            # 为每个分类组的最后一行添加底部边框（横线）
                                            if (length(group_end_rows) > 0) {
                                                for (end_row in group_end_rows) {
                                                    if (end_row < nrow(table_to_add)) {
                                                        n_cols <- length(colnames(table_to_add))
                                                        ft <- flextable::border(ft, 
                                                                               i = end_row, 
                                                                               j = seq_len(n_cols),
                                                                               border.bottom = officer::fp_border(color = "black", width = 1),
                                                                               part = "body")
                                                    }
                                                }
                                            }
                                            # 不应用自定义样式，使用 doc 的 "Normal Table" 样式
                                            # ft <- apply_table_style(ft)
                                            
                                            # 使用 doc 的 "Normal Table" 样式添加表格（性能优化：对于大表格跳过autofit）
                                            use_autofit <- nrow(table_to_add) < 100 && ncol(table_to_add) < 15
                                            doc <- add_table_to_doc(doc, ft, table_style = "Normal Table", use_autofit = use_autofit)
                                            cat("第", i, "行：写入表格", table_idx, "（合并单元格，样式：Normal Table）\n")
                                        } else {
                                            # 如果没有flextable，使用普通表格并应用 "Normal Table" 样式
                                            tryCatch({
                                                doc <- doc %>% body_add_table(table_to_add, style = "Normal Table")
                                                cat("第", i, "行：写入表格", table_idx, "（合并单元格，样式：Normal Table）\n")
                                            }, error = function(e) {
                                                # 如果样式失败，使用默认方式
                                                doc <<- doc %>% body_add_table(table_to_add)
                                                cat("第", i, "行：写入表格", table_idx, "（合并单元格，默认样式）\n")
                                            })
                                        }
                                    }
                                }
                            } else {
                                if (!is.null(table_to_add)) {
                                    # 检查是否为table_cnt_stu或table_cnt_tea（左右两列格式）
                                    is_cnt_table <- row$图表类型 %in% c("table_cnt_stu", "table_cnt_tea")
                                    has_left_right_format <- is_cnt_table && "分类.1" %in% colnames(table_to_add)
                                    
                                    if (has_left_right_format) {
                                        # table_cnt_stu和table_cnt_tea：左右两列格式，需要特殊处理
                                        if (requireNamespace("flextable", quietly = TRUE)) {
                                            ft <- flextable::flextable(table_to_add)
                                            
                                            # 修改表头显示：将右侧的"分类.1"、"类别.1"等改为"分类"、"类别"等
                                            header_labels <- as.list(colnames(table_to_add))
                                            names(header_labels) <- colnames(table_to_add)
                                            for (col_name in colnames(table_to_add)) {
                                                if (grepl("\\.1$", col_name)) {
                                                    base_name <- gsub("\\.1$", "", col_name)
                                                    if (base_name %in% colnames(table_to_add)) {
                                                        header_labels[[col_name]] <- base_name
                                                    }
                                                }
                                            }
                                            ft <- flextable::set_header_labels(ft, values = header_labels)
                                            
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
                                            # 左侧：只在左侧列（1-4列）添加底部边框
                                            if (length(left_group_end_rows) > 0) {
                                                for (end_row in left_group_end_rows) {
                                                    if (end_row < max_rows) {
                                                        ft <- flextable::border(ft, 
                                                                               i = end_row, 
                                                                               j = 1:4,  # 左侧4列：分类、类别、人数、百分比
                                                                               border.bottom = officer::fp_border(color = "black", width = 1),
                                                                               part = "body")
                                                    }
                                                }
                                            }
                                            
                                            # 右侧：只在右侧列（5-8列）添加底部边框
                                            if (length(right_group_end_rows) > 0) {
                                                for (end_row in right_group_end_rows) {
                                                    if (end_row < max_rows) {
                                                        ft <- flextable::border(ft, 
                                                                               i = end_row, 
                                                                               j = 5:8,  # 右侧4列：分类.1、类别.1、人数.1、百分比.1
                                                                               border.bottom = officer::fp_border(color = "black", width = 1),
                                                                               part = "body")
                                                    }
                                                }
                                            }
                                            
                                            # 使用 doc 的 "Normal Table" 样式添加表格
                                            use_autofit <- nrow(table_to_add) < 100 && ncol(table_to_add) < 15
                                            doc <- add_table_to_doc(doc, ft, table_style = "Normal Table", use_autofit = use_autofit)
                                            cat("第", i, "行：写入表格", table_idx, "（", row$图表类型, "，左右两列格式，样式：Normal Table）\n")
                                        } else {
                                            # 如果没有flextable，使用普通表格
                                            doc <- doc %>% body_add_table(table_to_add, style = "Normal Table")
                                            doc <- doc %>% officer::body_add_par("")
                                            cat("第", i, "行：写入表格", table_idx, "（", row$图表类型, "，注意：需要flextable包才能合并单元格）\n")
                                        }
                                    } else {
                                        # 普通表格（非table_basic_infor_figures，非table_cnt_stu/table_cnt_tea）：使用 "Normal Table" 样式
                                            ft <- flextable::flextable(table_to_add)
                                            
                                            # 如果是linear_regression，需要合并"变量类型"列的单元格
                                            if (row$图表类型 == "linear_regression" && "变量类型" %in% colnames(table_to_add)) {
                                                # 找到"变量类型"列的索引（第一列）
                                                var_type_col <- 1
                                                
                                                # 合并相同变量类型的单元格，并记录每个组的结束行
                                                current_type <- ""
                                                start_row <- 1
                                                group_end_rows <- c()  # 记录每个变量类型组的结束行（用于添加横线）
                                                
                                                for (r in seq_len(nrow(table_to_add))) {
                                                    if (table_to_add$变量类型[r] != current_type) {
                                                        if (current_type != "" && r > start_row) {
                                                            ft <- flextable::merge_at(ft, i = start_row:(r-1), j = var_type_col)
                                                            # 记录上一个组的结束行（r-1）
                                                            group_end_rows <- c(group_end_rows, r - 1)
                                                        }
                                                        current_type <- table_to_add$变量类型[r]
                                                        start_row <- r
                                                    }
                                                }
                                                # 合并最后一批
                                                if (start_row <= nrow(table_to_add)) {
                                                    ft <- flextable::merge_at(ft, i = start_row:nrow(table_to_add), j = var_type_col)
                                                    # 记录最后一个组的结束行（如果不是最后一行）
                                                    if (start_row <= nrow(table_to_add) - 1) {
                                                        group_end_rows <- c(group_end_rows, nrow(table_to_add))
                                                    }
                                                }
                                                
                                                # 为每个变量类型组的最后一行添加底部边框（横线）
                                                # 排除最后一行（因为表格本身已经有底部边框）
                                                if (length(group_end_rows) > 0) {
                                                    for (end_row in group_end_rows) {
                                                        if (end_row < nrow(table_to_add)) {
                                                            # 为该行的所有列添加底部边框
                                                            n_cols <- length(colnames(table_to_add))
                                                            ft <- flextable::border(ft, 
                                                                                i = end_row, 
                                                                                j = seq_len(n_cols),
                                                                                border.bottom = officer::fp_border(color = "black", width = 1),
                                                                                part = "body")
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            # 不应用自定义样式，使用 doc 的 "Normal Table" 样式
                                            # ft <- apply_table_style(ft)
                                            # 性能优化：对于大表格跳过autofit
                                            use_autofit <- nrow(table_to_add) < 100 && ncol(table_to_add) < 15
                                            
                                            # 如果是table_dims系列（table_dims_score/table_dims_figure/table_dims_figures_percent/table_dims_figures），需要特殊处理居中设置
                                            # 因为add_table_to_doc内部的set_table_width_and_autofit可能会重置对齐设置
                                            if (row$图表类型 %in% c("table_dims_score", "table_dims_figure", "table_dims_figures_percent", "table_dims_figures")) {
                                                # 先调用set_table_width_and_autofit（模拟add_table_to_doc内部的操作）
                                                if (use_autofit) {
                                                    ft <- set_table_width_and_autofit(ft)
                                                } else {
                                                    ft <- flextable::set_table_properties(ft, layout = "autofit", width = 1)
                                                }
                                                
                                                # 对于table_dims_figures和table_dims_figures_percent，所有单元格都居中
                                                if (row$图表类型 %in% c("table_dims_figures", "table_dims_figures_percent")) {
                                                    # 设置所有列都居中对齐（表头和主体）
                                                    # 使用明确的列索引确保所有列都被设置
                                                    n_cols <- ncol(table_to_add)
                                                    # 先设置表头居中
                                                    ft <- ft %>% flextable::align(align = "center", j = seq_len(n_cols), part = "header")
                                                    # 再设置主体居中
                                                    ft <- ft %>% flextable::align(align = "center", j = seq_len(n_cols), part = "body")
                                                    # 最后再次确认所有列都居中（防止被覆盖）
                                                    ft <- ft %>% flextable::align(align = "center", j = seq_len(n_cols), part = "all")
                                                } else {
                                                    # 对于table_dims_score和table_dims_figure，保持原有逻辑（包含"变量"或"题目"的列居左）
                                                    # 然后设置居中（确保在autofit和set_table_properties之后，包括表头和主体）
                                                    # 注意：必须在所有表格属性设置之后设置对齐，否则可能被重置
                                                    ft <- ft %>% flextable::align(align = "center", part = "header") %>%
                                                                flextable::align(align = "center", part = "body")
                                                    
                                                    # 列名包含"变量"或"题目"的列设置为居左对齐
                                                    col_names <- colnames(table_to_add)
                                                    left_align_cols <- which(grepl("变量|题目", col_names))
                                                    if (length(left_align_cols) > 0) {
                                                        ft <- ft %>% flextable::align(align = "left", j = left_align_cols, part = "header") %>%
                                                                    flextable::align(align = "left", j = left_align_cols, part = "body")
                                                    }
                                                    
                                                    # 再次确保所有列都居中对齐（除了已设置为居左的列）
                                                    # 这可以防止某些操作重置对齐设置
                                                    all_cols <- seq_len(ncol(table_to_add))
                                                    center_cols <- setdiff(all_cols, left_align_cols)
                                                    if (length(center_cols) > 0) {
                                                        ft <- ft %>% flextable::align(align = "center", j = center_cols, part = "header") %>%
                                                                    flextable::align(align = "center", j = center_cols, part = "body")
                                                    }
                                                }
                                                
                                                # 直接添加到文档（跳过add_table_to_doc内部的表头居中设置）
                                                doc <- doc %>% flextable::body_add_flextable(ft)
                                                doc <- doc %>% officer::body_add_par("")
                                            } else {
                                                doc <- add_table_to_doc(doc, ft, table_style = "Normal Table", use_autofit = use_autofit)
                                            }
                                            cat("第", i, "行：写入表格", table_idx, "（使用flextable，样式：Normal Table）\n")
                                    }
                                }
                            }
                        }  # 结束处理每个表格的循环
                        
                    }, error = function(e) {
                        error_msg <- paste("写入表格失败：", e$message)
                        warning(paste("第", i, "行：", error_msg))
                        # 记录失败（性能优化：使用list追加而不是rbind）
                        failed_charts$行号 <<- c(failed_charts$行号, i)
                        failed_charts$图表类型 <<- c(failed_charts$图表类型, ifelse(is.na(row$图表类型), "", as.character(row$图表类型)))
                        failed_charts$报告维度 <<- c(failed_charts$报告维度, ifelse(is.na(row$报告维度), "", as.character(row$报告维度)))
                        failed_charts$失败原因 <<- c(failed_charts$失败原因, error_msg)
                    })
                }
                
                # 如果是图片
                if (!is.null(chart_obj$plot) || (inherits(chart_obj, "ggplot"))) {
                    tryCatch({
                        # 保存临时图片
                        temp_file <- tempfile(fileext = ".png")
                        
                        # 确定图片高度
                        plot_height <- 3.5  # 默认高度
                        # 先检查 chart_obj 本身是否是 ggplot 对象
                        if (inherits(chart_obj, "ggplot")) {
                            # 检查是否有存储的高度信息（从plot对象本身获取）
                            if (!is.null(attr(chart_obj, "plot_height"))) {
                                plot_height <- attr(chart_obj, "plot_height")
                            } else {
                                # 根据图表类型设置默认高度
                                chart_type <- row$图表类型
                                if (chart_type == "simple_bar_dis_figures") {
                                    plot_height <- 2.5
                                } else if (chart_type == "simple_bar_subdim_figures" || chart_type == "simple_bar_subdim_score") {
                                    plot_height <- 2.5
                                } else if (grepl("difference_class", chart_type)) {
                                    plot_height <- 3
                                } else if (chart_type == "pie_distribution") {
                                    plot_height <- 2.5  # 饼图高度
                                } else if (chart_type == "pie_distribution_trans_bar") {
                                    plot_height <- 3  # 条形图高度
                                } else if (chart_type == "stack_bar_change_y") {
                                    # stack_bar_change_y的高度已经在plot对象中设置
                                    plot_height <- 4  # 默认值，实际会从attr获取
                                }
                            }
                            ggsave(temp_file, chart_obj, width = 5.5, height = plot_height, dpi = 300)
                        } else if (!is.null(chart_obj$plot)) {
                            if (inherits(chart_obj$plot, "gtable")) {
                                # 如果是arrangeGrob的结果（合并的图片）
                                # 尝试从gtable中获取布局信息来估算行数和列数
                                gtable_obj <- chart_obj$plot
                                # 估算行数和列数
                                layout_rows <- unique(gtable_obj$layout$t)
                                layout_cols <- unique(gtable_obj$layout$l)
                                n_rows_est <- length(layout_rows)
                                n_cols_est <- length(layout_cols)
                                
                                # 使用与单个图片相同的尺寸比例，确保字体大小一致
                                # 单个图片：宽度5.5英寸，高度约2.5-3英寸
                                single_width <- 5.5  # 单个图片宽度（英寸）
                                single_height <- 1.8  # 单个图片高度（英寸），保持与单个图片一致
                                
                                # 计算总尺寸：每个子图保持原始尺寸
                                # 标题空间（如果有）
                                title_space <- ifelse(n_rows_est >= 2, 0.3, 0.2)
                                plot_height <- n_rows_est * single_height + title_space
                                plot_width <- n_cols_est * single_width
                                
                                # 限制最大高度，避免图片过高（最多7英寸）
                                if (plot_height > 7) {
                                    plot_height <- 7
                                }
                                
                                # 转换为像素（300 DPI，与单个图片保持一致）
                                img_width <- round(plot_width * 300)
                                img_height <- round(plot_height * 300)
                                
                                png(temp_file, width = img_width, height = img_height, res = 300)
                                grid.draw(chart_obj$plot)
                                dev.off()
                            } else if (inherits(chart_obj$plot, "patchwork")) {
                                # 如果是patchwork的结果（合并的图片）
                                # patchwork会自动保持原始尺寸，不需要拉伸
                                patchwork_obj <- chart_obj$plot
                                
                                # 尝试从patchwork对象中获取布局信息
                                # patchwork对象有$patches$layout属性
                                n_rows_est <- NULL
                                n_cols_est <- NULL
                                if (!is.null(patchwork_obj$patches) && !is.null(patchwork_obj$patches$layout)) {
                                    layout <- patchwork_obj$patches$layout
                                    if (!is.null(layout$nrow)) n_rows_est <- layout$nrow
                                    if (!is.null(layout$ncol)) n_cols_est <- layout$ncol
                                }
                                
                                # 如果无法获取布局信息，尝试从图表类型推断
                                if (is.null(n_rows_est) || is.null(n_cols_est)) {
                                    chart_type <- row$图表类型
                                    if (grepl("difference_class", chart_type)) {
                                        # difference_class通常有多个Y变量，默认2列
                                        n_cols_est <- 2
                                        # 需要知道Y变量数量，这里使用默认值
                                        n_rows_est <- 2
                                    } else {
                                        n_cols_est <- 2
                                        n_rows_est <- 1
                                    }
                                }
                                
                                # 使用与单个图片相同的尺寸比例，确保字体大小一致
                                single_width <- 5.5  # 单个图片宽度（英寸）
                                single_height <- 1.8  # 单个图片高度（英寸），保持与单个图片一致
                                
                                # 计算总尺寸：每个子图保持原始尺寸
                                # patchwork会自动处理标题空间
                                title_space <- ifelse(n_rows_est >= 2, 0.3, 0.2)
                                plot_height <- n_rows_est * single_height + title_space
                                plot_width <- n_cols_est * single_width
                                
                                # 限制最大高度，避免图片过高（最多7英寸）
                                if (plot_height > 7) {
                                    plot_height <- 7
                                }
                                
                                # 使用ggsave保存patchwork对象，它会自动保持原始尺寸和字体大小
                                ggsave(temp_file, patchwork_obj, width = plot_width, height = plot_height, dpi = 300)
                        } else {
                            # 检查是否有存储的高度信息
                            if (!is.null(attr(chart_obj$plot, "plot_height"))) {
                                plot_height <- attr(chart_obj$plot, "plot_height")
                            } else {
                                # 根据图表类型设置默认高度
                                chart_type <- row$图表类型
                                if (chart_type == "simple_bar_dis_figures") {
                                    plot_height <- 2.15
                                } else if (chart_type == "simple_bar_subdim_figures" || chart_type == "simple_bar_subdim_score") {
                                    plot_height <- 2.5
                                } else if (grepl("difference_class", chart_type)) {
                                    plot_height <- 2.5
                                } else if (chart_type == "pie_distribution") {
                                    plot_height <- 2.5  # 饼图高度
                                } else if (chart_type == "pie_distribution_trans_bar") {
                                    plot_height <- 2.5  # 条形图高度
                                } else if (chart_type == "stack_bar_change_y") {
                                    plot_height <- 4  # stack_bar_change_y默认高度（实际会从attr获取）
                                }
                            }
                            # 调试信息：写入前记录数据（输出完整的标签数据）
                            if (row$图表类型 == "stack_bar_change_y") {
                                cat("【写入时】第", i, "行：stack_bar_change_y准备写入图片\n")
                                cat("  chart_obj$table行数:", nrow(chart_obj$table), "\n")
                                cat("  完整数据（Y类别 | stack类别 | 占比 | Lable）：\n")
                                for (r in 1:nrow(chart_obj$table)) {
                                    cat("    行", r, ":", as.character(chart_obj$table$Y类别[r]), "|", 
                                        as.character(chart_obj$table$stack类别[r]), "|", 
                                        chart_obj$table$占比[r], "|", 
                                        ifelse("Lable" %in% colnames(chart_obj$table), chart_obj$table$Lable[r], ""), "\n")
                                }
                                # 检查plot对象中的数据快照
                                if (!is.null(attr(chart_obj$plot, "data_snapshot"))) {
                                    snapshot <- attr(chart_obj$plot, "data_snapshot")
                                    cat("  plot对象快照 - 行数:", snapshot$nrow, "\n")
                                    if (!is.null(snapshot$full_table)) {
                                        cat("  plot对象快照 - 完整数据（Y类别 | stack类别 | 占比 | Lable）：\n")
                                        for (r in 1:nrow(snapshot$full_table)) {
                                            cat("    行", r, ":", as.character(snapshot$full_table$Y类别[r]), "|", 
                                                as.character(snapshot$full_table$stack类别[r]), "|", 
                                                snapshot$full_table$占比[r], "|", 
                                                ifelse("Lable" %in% colnames(snapshot$full_table), snapshot$full_table$Lable[r], ""), "\n")
                                        }
                                    } else {
                                        cat("  plot对象快照 - Y类别:", paste(snapshot$Y_categories, collapse = ", "), "\n")
                                    }
                                } else {
                                    cat("  警告：plot对象没有数据快照属性\n")
                                }
                            }
                            ggsave(temp_file, chart_obj$plot, width = 5.5, height = plot_height, dpi = 300)
                            }
                        }
                        
                        if (file.exists(temp_file)) {
                            # 减小宽度以适应Word边距
                            doc <- doc %>% body_add_img(temp_file, width = 5.5, height = plot_height)
                            doc <- doc %>% officer::body_add_par("")  # 图片后添加空行
                            cat("第", i, "行：写入图片（高度：", plot_height, "）\n")
                        } else {
                            # 图片文件未生成
                            error_msg <- "图片文件未生成"
                            failed_charts <<- rbind(failed_charts, data.frame(
                                行号 = i,
                                图表类型 = ifelse(is.na(row$图表类型), "", as.character(row$图表类型)),
                                报告维度 = ifelse(is.na(row$报告维度), "", as.character(row$报告维度)),
                                失败原因 = error_msg,
                                stringsAsFactors = FALSE
                            ))
                        }
                    }, error = function(e) {
                        error_msg <- paste("写入图片失败：", e$message)
                        warning(paste("第", i, "行：", error_msg))
                        # 记录失败（性能优化：使用list追加而不是rbind）
                        failed_charts$行号 <<- c(failed_charts$行号, i)
                        failed_charts$图表类型 <<- c(failed_charts$图表类型, ifelse(is.na(row$图表类型), "", as.character(row$图表类型)))
                        failed_charts$报告维度 <<- c(failed_charts$报告维度, ifelse(is.na(row$报告维度), "", as.character(row$报告维度)))
                        failed_charts$失败原因 <<- c(failed_charts$失败原因, error_msg)
                    })
                }
            } else {
                error_msg <- paste("未找到图表对象", chart_obj_name)
                warning(paste("第", i, "行：", error_msg))
                # 记录失败（如果还没有记录过）
                # 检查failed_charts是list还是data.frame
                if (is.list(failed_charts)) {
                    # 如果是list，检查是否已经记录过
                    if (length(failed_charts$行号) == 0 || !any(failed_charts$行号 == i, na.rm = TRUE)) {
                        failed_charts$行号 <<- c(failed_charts$行号, i)
                        failed_charts$图表类型 <<- c(failed_charts$图表类型, ifelse(is.na(row$图表类型), "", as.character(row$图表类型)))
                        failed_charts$报告维度 <<- c(failed_charts$报告维度, ifelse(is.na(row$报告维度), "", as.character(row$报告维度)))
                        failed_charts$失败原因 <<- c(failed_charts$失败原因, error_msg)
                    }
                } else {
                    # 如果是data.frame，使用原来的逻辑
                    if (nrow(failed_charts) == 0 || !any(failed_charts$行号 == i, na.rm = TRUE)) {
                        failed_charts <<- rbind(failed_charts, data.frame(
                            行号 = i,
                            图表类型 = ifelse(is.na(row$图表类型), "", as.character(row$图表类型)),
                            报告维度 = ifelse(is.na(row$报告维度), "", as.character(row$报告维度)),
                            失败原因 = error_msg,
                            stringsAsFactors = FALSE
                        ))
                    }
                }
            }
        }
    }
    
    cat("写入完成，共写入", written_rows, "行\n")
    
    # 性能优化：将list转换为data.frame（只在最后转换一次）
    if (is.list(failed_charts) && length(failed_charts$行号) > 0) {
        failed_charts <- data.frame(
            行号 = failed_charts$行号,
            图表类型 = failed_charts$图表类型,
            报告维度 = failed_charts$报告维度,
            失败原因 = failed_charts$失败原因,
            stringsAsFactors = FALSE
        )
    } else if (is.list(failed_charts)) {
        # 如果没有失败记录，返回空的data.frame
        failed_charts <- data.frame(
            行号 = integer(),
            图表类型 = character(),
            报告维度 = character(),
            失败原因 = character(),
            stringsAsFactors = FALSE
        )
    }
    
    return(list(doc = doc, failed_charts = failed_charts))
}

########################################################
# 文本生成函数（用于区级报告）
########################################################
# chart_obj, chart_type, row, d, dat_for_chart, figures_with_dot

generate_text_for_chart <- function(chart_obj, chart_type, row, d, dat, figures_with_dot = NULL, index_item = NULL,
                                    is_three_level_compare = FALSE, school_district = NULL) {
    if (chart_type %in% c("multichoice_distribution")) {
        # 第1种text：找出数值最大的前3个类别
        if (is.null(chart_obj$table) || nrow(chart_obj$table) == 0) {
            return(NULL)
        }
        
        table_data <- chart_obj$table
        if (!"指标" %in% colnames(table_data) || !"值" %in% colnames(table_data)) {
            return(NULL)
        }
        
        # 按值排序，取前3个
        table_sorted <- table_data[order(table_data$值, decreasing = TRUE), ]
        top3 <- head(table_sorted, 3)
        
        if (nrow(top3) == 0) {
            return(NULL)
        }
        
        # 获取title
        title <- ifelse(is.na(row$图题表题) || row$图题表题 == "", "", row$图题表题)
        title <- gsub("分布情况", "", title)
        
        # 格式化数值
        if (chart_type == "multichoice_distribution") {
            # 百分比类型，值已经是百分比
            num_max_1 <- paste0(round(top3$值[1], 1), "%")
            num_max_2 <- ifelse(nrow(top3) >= 2, paste0(round(top3$值[2], 1), "%"), "")
            num_max_3 <- ifelse(nrow(top3) >= 3, paste0(round(top3$值[3], 1), "%"), "")
        } else {
            # 非百分比类型
            num_max_1 <- round(top3$值[1], 1)
            num_max_2 <- ifelse(nrow(top3) >= 2, round(top3$值[2], 1), "")
            num_max_3 <- ifelse(nrow(top3) >= 3, round(top3$值[3], 1), "")
        }
        
        var_max_1 <- top3$指标[1]
        var_max_2 <- ifelse(nrow(top3) >= 2, top3$指标[2], "")
        var_max_3 <- ifelse(nrow(top3) >= 3, top3$指标[3], "")
        
        # 组合文本
        if (nrow(top3) == 1) {
            text <- paste0("在", title, "方面，选择最多的1项为：", var_max_1, "（", num_max_1, "）。")
        } else if (nrow(top3) == 2) {
            text <- paste0("在", title, "方面，选择最多的2项为：", var_max_1, "（", num_max_1, "）、", var_max_2, "（", num_max_2, "）。")
        } else {
            text <- paste0("在", title, "方面，选择最多的3项为：", var_max_1, "（", num_max_1, "）、", var_max_2, "（", num_max_2, "）、", var_max_3, "（", num_max_3, "）。")
        }
        
        return(text)
        
    } else if (chart_type %in% c("multichoice_distribution_non_percent")) {
        # 第1种text变体：找出数值最大的前3个类别，使用写死的维度名称
        if (is.null(chart_obj$table) || nrow(chart_obj$table) == 0) {
            return(NULL)
        }
        
        table_data <- chart_obj$table
        if (!"指标" %in% colnames(table_data) || !"值" %in% colnames(table_data)) {
            return(NULL)
        }
        
        # 按值排序，取前3个
        table_sorted <- table_data[order(table_data$值, decreasing = TRUE), ]
        top3 <- head(table_sorted, 3)
        
        if (nrow(top3) == 0) {
            return(NULL)
        }
        
        # 获取指标名称（不包含数值）
        var_max_1 <- top3$指标[1]
        var_max_2 <- ifelse(nrow(top3) >= 2, top3$指标[2], "")
        var_max_3 <- ifelse(nrow(top3) >= 3, top3$指标[3], "")
        
        # 组合文本（维度名称写死为"教师每周占用教师时间最多的前三项工作内容"）
        if (nrow(top3) == 1) {
            text <- paste0("评估结果显示，教师每周占用教师时间最多的前三项工作内容是：", var_max_1, "。")
        } else if (nrow(top3) == 2) {
            text <- paste0("评估结果显示，教师每周占用教师时间最多的前三项工作内容是：", var_max_1, "、", var_max_2, "。")
        } else {
            text <- paste0("评估结果显示，教师每周占用教师时间最多的前三项工作内容是：", var_max_1, "、", var_max_2, "、", var_max_3, "。")
        }
        
        return(text)
        
    } else if (chart_type %in% c("simple_bar_dis_figures", "simple_bar_dis_figures_percent", "simple_bar_dis_score")) {
        # 第2种text：比较当前d区与青岛市（或三级对比：本校、区市、青岛市）
        if (is.null(chart_obj$table) || nrow(chart_obj$table) == 0) {
            return(NULL)
        }
        
        table_data <- chart_obj$table
        if (!"区市" %in% colnames(table_data) || !"值" %in% colnames(table_data)) {
            return(NULL)
        }
        
        if (is_three_level_compare) {
            # 三级对比：比较本校、区市、青岛市
            sch_value_row <- table_data[table_data$区市 == "本校", ]
            dist_value_row <- table_data[table_data$区市 == school_district, ]
            qingdao_value_row <- table_data[table_data$区市 == "青岛市", ]
            
            if (nrow(sch_value_row) == 0 || nrow(dist_value_row) == 0 || nrow(qingdao_value_row) == 0) {
                return(NULL)
            }
            
            sch_value <- sch_value_row$值_pct[1]
            dist_value <- dist_value_row$值_pct[1]
            qingdao_value <- qingdao_value_row$值_pct[1]
            
            # 使用本校的值作为主要值
            d_value <- sch_value
        } else {
            # 原有逻辑：比较当前d区与青岛市
            # 获取当前d区的值
            d_value_row <- table_data[table_data$区市 == d, ]
            if (nrow(d_value_row) == 0) {
                return(NULL)
            }
            d_value <- d_value_row$值_pct[1]
            
            # 获取青岛市的值
            qingdao_value_row <- table_data[table_data$区市 == "青岛市", ]
            if (nrow(qingdao_value_row) == 0) {
                return(NULL)
            }
            qingdao_value <- qingdao_value_row$值_pct[1]
        }
        
        # 确定suffix和role
        if (chart_type == "simple_bar_dis_score") {
            suffix <- "分数"
        } else if (chart_type == "simple_bar_dis_figures_percent") {
            suffix <- "指数"
        } else {
            suffix <- "指数"
        }
        
        role <- ifelse(!is.na(row$数据表对应) && row$数据表对应 == "tea", "教师", "学生")
        
        # 获取报告维度作为title
        dim <- ifelse(is.na(row$报告维度) || row$报告维度 == "", "", row$报告维度)
        title <- paste0(dim, suffix)
        
        # 确定小数位数（用于比较和显示）
        if (chart_type == "simple_bar_dis_score") {
            decimal_digits <- 1
        } else {
            if (is.null(figures_with_dot)) {
                figures_with_dot <- c()
            }
            use_decimal <- dim %in% figures_with_dot
            decimal_digits <- ifelse(use_decimal, 1, 0)
        }
        
        # 对值进行round，确保小数位数一致
        d_value_rounded <- round(d_value, decimal_digits)
        qingdao_value_rounded <- round(qingdao_value, decimal_digits)
        
        # # 比较（使用round后的值）        
        # if (d_value_rounded > qingdao_value_rounded) {
        #     compare <- "高于青岛市"
        # } else if (d_value_rounded < qingdao_value_rounded) {
        #     compare <- "低于青岛市"
        # } else {
        #     compare <- "大约与青岛市齐平"
        # }
        
        # 组合文本（使用round后的值显示）
        # text <- paste0("评估显示，", role,  title, "为", d_value_rounded, "（", compare, "）。")
        
        # 确定是否需要添加%符号：如果是simple_bar_dis_percent类型，或者dim在figures_with_dot中
        need_percent <- chart_type == "simple_bar_dis_figures_percent" || (!is.null(figures_with_dot) && dim %in% figures_with_dot)
        text <- ifelse(need_percent,
            paste0("评估显示，", role,  title, "为", d_value_rounded,  "%。"),
            paste0("评估显示，", role,  title, "为", d_value_rounded,  "。"))
        # 如果出现“总分分数”，将会被替换为“平均分”
        text <- gsub("总分分数", "平均分", text)
        return(text)
        
    } else if (chart_type == "stack_bar_var_distribution" || chart_type == "stack_bar_var_distribution_sch") {
        # 第3种text：stack_bar_var_distribution（含 stack_bar_var_distribution_sch）的文本生成
        if (is.null(chart_obj$table) || nrow(chart_obj$table) == 0) {
            return(NULL)
        }
        
        table_data <- chart_obj$table
        if (!"Y类别" %in% colnames(table_data) || !"stack类别" %in% colnames(table_data) || !"占比" %in% colnames(table_data)) {
            return(NULL)
        }
        
        # 检查交叉或分类变量是否为"区市"
        Y_var <- row$交叉或分类变量
        if (is.na(Y_var) || Y_var == "") {
            return(NULL)
        }
        
        # 获取参数：计算哪几个类别的加和，从row$sum_indices读取
        sum_indices_str <- row$sum_indices
        # 如果为空或NA，不需要text，返回NULL
        if (is.na(sum_indices_str) || sum_indices_str == "" || trimws(sum_indices_str) == "") {
            return(NULL)
        }
        
        # 解析sum_indices字符串
        # 如果包含&，则分割；否则作为单个数字
        if (grepl("&", sum_indices_str, fixed = TRUE)) {
            # 多个数字，用&分隔，如 "2&3"
            sum_indices <- suppressWarnings(as.numeric(strsplit(sum_indices_str, "&", fixed = TRUE)[[1]]))
        } else {
            # 单个数字，如 "1"
            sum_indices <- suppressWarnings(as.numeric(sum_indices_str))
        }
        
        # 检查解析结果是否有效
        if (any(is.na(sum_indices)) || length(sum_indices) == 0) {
            return(NULL)
        }
        
        # 获取dim_or_item
        dim_or_item <- row$dim_or_item
        if (is.na(dim_or_item) || dim_or_item == "") {
            return(NULL)
        }
        
        # 提取类别名称
        stack_categories <- c()
        
        if (dim_or_item == "dim") {
            # 从index_item中获取报告维度分类名
            if (is.null(index_item)) {
                return(NULL)
            }
            
            dim_value <- row$报告维度
            if (is.na(dim_value) || dim_value == "") {
                return(NULL)
            }
            
            # 根据数据表对应过滤index_item
            index_item_filtered <- filter_index_item_by_data_table(index_item, row)
            
            # 先尝试报告维度匹配
            item_row <- index_item_filtered %>% filter(报告维度 == dim_value) %>% slice(1)
            if (nrow(item_row) == 0) {
                # 如果失败，尝试子维度匹配
                item_row <- index_item_filtered %>% filter(子维度 == dim_value) %>% slice(1)
            }
            
            if (nrow(item_row) == 0) {
                return(NULL)
            }
            
            # 获取报告维度分类名1到10
            for (j in 1:10) {
                col_name <- paste0("报告维度分类名", j)
                if (col_name %in% colnames(index_item_filtered)) {
                    cat_val <- item_row[[col_name]]
                    if (!is.na(cat_val) && cat_val != "") {
                        stack_categories <- c(stack_categories, as.character(cat_val))
                    }
                }
            }
            
        } else if (dim_or_item == "item") {
            # 从index_item中获取选项列
            if (is.null(index_item)) {
                return(NULL)
            }
            
            item_value <- row$报告维度
            if (is.na(item_value) || item_value == "") {
                return(NULL)
            }
            
            # 根据数据表对应过滤index_item
            index_item_filtered <- filter_index_item_by_data_table(index_item, row)
            
            item_row <- index_item_filtered %>% filter(题目列名 == item_value) %>% slice(1)
            if (nrow(item_row) == 0) {
                return(NULL)
            }
            
            options_str <- item_row$选项
            if (is.na(options_str) || options_str == "") {
                return(NULL)
            }
            
            # 用//C//分割
            stack_categories <- strsplit(options_str, "//C//", fixed = TRUE)[[1]]
            stack_categories <- trimws(stack_categories)
            
        } else if (dim_or_item == "basic") {
            # 从数据中直接获取类别，按照dat[[对应数据列]]的levels顺序
            if (is.null(dat)) {
                # 如果dat不可用，从图表数据表中获取唯一值
                stack_categories <- unique(table_data$stack类别[!is.na(table_data$stack类别)])
                stack_categories <- as.character(stack_categories)
            } else {
                # 确定对应的数据列
                basic_col <- row$报告维度
                if (!is.na(basic_col) && basic_col != "" && basic_col %in% colnames(dat)) {
                    # 判断当前变量是否为factor
                    if (is.factor(dat[[basic_col]])) {
                        stack_categories <- levels(dat[[basic_col]])
                    } else {
                        stack_categories <- unique(dat[[basic_col]])
                        stack_categories <- stack_categories[!is.na(stack_categories)]
                        stack_categories <- as.character(stack_categories)
                    }
                } else {
                    # 如果找不到对应的列，从图表数据表中获取唯一值
                    stack_categories <- unique(table_data$stack类别[!is.na(table_data$stack类别)])
                    stack_categories <- as.character(stack_categories)
                }
            }
        }
        
        if (length(stack_categories) == 0) {
            return(NULL)
        }
        
        # 检查sum_indices是否有效
        valid_indices <- sum_indices[sum_indices >= 1 & sum_indices <= length(stack_categories)]
        if (length(valid_indices) == 0) {
            return(NULL)
        }
        
        # 获取需要加和的类别名称
        class <- stack_categories[valid_indices]
        class_text <- paste(class, collapse = "或")
        
        # 计算必要数据
        role <- case_when(
            !is.na(row$数据表对应) && row$数据表对应 == "tea" ~ "教师",
            !is.na(row$数据表对应) && row$数据表对应 %in% c("stu", "stu_par") ~ "学生",
            !is.na(row$数据表对应) && row$数据表对应 == "par" ~ "家庭",
            TRUE ~ "学生"
        )
        
        # 判断是区市还是其他交叉或分类变量
        if (Y_var == "区市") {
            # 区市的逻辑：比较d区与青岛市
            # 如果是三级对比模式（学校报告），表格中的Y类别是"本校"，应该使用"本校"来匹配
            # 如果是非三级对比模式（区级报告），表格中的Y类别是区名（如"城阳区"），应该使用d来匹配
            target_y_category <- if (is_three_level_compare) "本校" else d
            
            # 计算目标类别占比的和
            d_data <- table_data[table_data$Y类别 == target_y_category & table_data$stack类别 %in% class, ]
            if (nrow(d_data) == 0) {
                return(NULL)
            }
            pct_sum_d <- round(sum(d_data$占比, na.rm = TRUE), 1)
            
            # 计算青岛市类别占比的和
            qingdao_data <- table_data[table_data$Y类别 == "青岛市" & table_data$stack类别 %in% class, ]
            if (nrow(qingdao_data) == 0) {
                return(NULL)
            }
            pct_sum_all <- round(sum(qingdao_data$占比, na.rm = TRUE), 1)
            


            # # 比较
            # if (pct_sum_d > pct_sum_all) {
            #     compare <- "高于青岛市"
            # } else if (pct_sum_d < pct_sum_all) {
            #     compare <- "低于青岛市"
            # } else {
            #     compare <- "大约与青岛市齐平"
            # }
            
            # # 拼接文本
            # if (dim_or_item == "dim") {
            #     dim_name <- row$报告维度
            #     text <- paste0("在", dim_name, "上，", pct_sum_d, "%的", role, "达到", class_text, "的水平，", compare, "。")
            # } else if (dim_or_item == "item") {
            #     title <- ifelse(is.na(row$图题表题) || row$图题表题 == "", "", row$图题表题)
            #     title <- gsub("情况对比|基本情况|情况|各区市", "", title)
            #     text <- paste0("在", title, "上，", pct_sum_d, "%的", role, "选择了", class_text, "，", compare, "。")
            # } else {
            #     # basic类型，使用报告维度
            #     dim_name <- row$报告维度
            #     text <- paste0("在", dim_name, "上，", pct_sum_d, "%的", role, "达到", class_text, "的水平，", compare, "。")
            # }
            
            # 拼接文本
            if (dim_or_item == "dim") {
                dim_name <- row$报告维度
                text <- paste0("在", dim_name, "上，", pct_sum_d, "%的", role, "达到", class_text, "的水平。")
            } else if (dim_or_item == "item") {
                title <- ifelse(is.na(row$图题表题) || row$图题表题 == "", "", row$图题表题)
                title <- gsub("情况对比|基本情况|情况|各区市", "", title)
                text <- paste0("在", title, "上，", pct_sum_d, "%的", role, "选择了", class_text, "。")
            } else {
                # basic类型，使用报告维度
                dim_name <- row$报告维度
                text <- paste0("在", dim_name, "上，", pct_sum_d, "%的", role, "达到", class_text, "的水平。")
            }

            return(text)
            
        } else {
            # 其他交叉或分类变量的逻辑：为每个Y类别生成一行文本
            # 获取交叉或分类变量的所有类别（class_y）
            class_y <- unique(table_data$Y类别[!is.na(table_data$Y类别)])
            class_y <- as.character(class_y)
            
            if (length(class_y) == 0) {
                return(NULL)
            }
            
            # 将Y_var从英文变量名转换为中文名称（如果存在映射）
            basic_var_mapping <- list(
                Gen = "性别",
                Loc = "城乡",
                Fam = "家庭结构",
                Sim = "子女数量",
                Edu_m = "母亲学历",
                Edu_f = "父亲学历",
                "SES" = "家庭教育投入",
                Tit = "职称",
                Age = "年龄",
                Exp = "教龄",
                Edu = "学历",
                Pos = "职务"
            )
            
            # 如果Y_var在映射中，则使用中文名称，否则保持原样
            if (Y_var %in% names(basic_var_mapping)) {
                Y_var_display <- basic_var_mapping[[Y_var]]
            } else {
                Y_var_display <- Y_var
                
                ## 特殊变量：如果Y_var_display等于特定字符串，则替换为友好的显示名称
                if (Y_var_display == "12.今年，您在孩子学科课外辅导的支出大约是：（单选题）_合并") {
                    Y_var_display <- "学科课外辅导支出"
                } else if (Y_var_display == "13.您家里大概有多少本书（不包括报刊、杂志、学生课本及教辅）？（单选题）") {
                    Y_var_display <- "家庭藏书量"
                }
            }
            
            # 为每个class_y计算pct_sum并生成文本
            text_parts <- c()
            # 获取报告维度名称
            dim_name <- ifelse(is.na(row$报告维度) || row$报告维度 == "", "", row$报告维度)
            
            first_sentence <- TRUE  # 标记是否是第一个句子
            for (y_cat in class_y) {
                # 计算该类别下class的占比和
                y_data <- table_data[table_data$Y类别 == y_cat & table_data$stack类别 %in% class, ]
                if (nrow(y_data) > 0) {
                    pct_sum <- round(sum(y_data$占比, na.rm = TRUE), 1)
                    # 拼接文本：第一个句子包含"在dim_name"，后面的句子不包含
                    if (first_sentence) {
                        text_part <- paste0("当", Y_var_display, "为", y_cat, "时，", pct_sum, "%的", role, "在", dim_name, "达到", class_text, "的水平；")
                        first_sentence <- FALSE
                    } else {
                        text_part <- paste0("当", Y_var_display, "为", y_cat, "时，", pct_sum, "%的", role, "达到", class_text, "的水平；")
                    }
                    text_parts <- c(text_parts, text_part)
                }
            }
            
            if (length(text_parts) == 0) {
                return(NULL)
            }
            
            # 将所有文本部分组合，最后一个用句号结尾
            text <- paste(text_parts, collapse = "")
            # 将最后一个分号替换为句号
            text <- gsub("；$", "。", text)
            
            return(text)
        }
    } else if (chart_type %in% c("pie_distribution", "pie_distribution_trans_bar")) {
        # 第4种text：pie_distribution的文本生成
        if (is.null(chart_obj$table) || nrow(chart_obj$table) == 0) {
            return(NULL)
        }
        
        table_data <- chart_obj$table
        if (!"类别" %in% colnames(table_data) || !"占比" %in% colnames(table_data)) {
            return(NULL)
        }
        
        # 检查sum_indices是否不为NA
        sum_indices_str <- row$sum_indices
        if (is.na(sum_indices_str) || sum_indices_str == "" || trimws(sum_indices_str) == "") {
            return(NULL)
        }
        
        # 获取dim_or_item
        dim_or_item <- row$dim_or_item
        if (is.na(dim_or_item) || dim_or_item == "") {
            return(NULL)
        }
        
        # 计算必要数据
        role <- case_when(
            !is.na(row$数据表对应) && row$数据表对应 == "tea" ~ "教师",
            !is.na(row$数据表对应) && row$数据表对应 %in% c("stu", "stu_par") ~ "学生",
            !is.na(row$数据表对应) && row$数据表对应 == "par" ~ "家庭",
            TRUE ~ "学生"
        )
        
        if (sum_indices_str == "all") {
            # 情况1：sum_indices == "all"，按照分类的顺序依次得到各分类的占比，中间分号分隔
            # 按照正确的顺序获取类别
            categories <- c()
            
            if (dim_or_item == "dim") {
                # 从index_item中获取报告维度分类名
                if (!is.null(index_item)) {
                    dim_value <- row$报告维度
                    if (!is.na(dim_value) && dim_value != "") {
                        # 根据数据表对应过滤index_item
                        index_item_filtered <- filter_index_item_by_data_table(index_item, row)
                        
                        # 先尝试报告维度匹配
                        item_row <- index_item_filtered %>% filter(报告维度 == dim_value) %>% slice(1)
                        if (nrow(item_row) == 0) {
                            # 如果失败，尝试子维度匹配
                            item_row <- index_item_filtered %>% filter(子维度 == dim_value) %>% slice(1)
                        }
                        
                        if (nrow(item_row) > 0) {
                            # 获取报告维度分类名1到10
                            for (j in 1:10) {
                                col_name <- paste0("报告维度分类名", j)
                                if (col_name %in% colnames(index_item_filtered)) {
                                    cat_val <- item_row[[col_name]]
                                    if (!is.na(cat_val) && cat_val != "") {
                                        categories <- c(categories, as.character(cat_val))
                                    }
                                }
                            }
                        }
                    }
                }
            } else if (dim_or_item == "item") {
                # 从index_item中获取选项列
                if (!is.null(index_item)) {
                    item_value <- row$报告维度
                    if (!is.na(item_value) && item_value != "") {
                        # 根据数据表对应过滤index_item
                        index_item_filtered <- filter_index_item_by_data_table(index_item, row)
                        
                        item_row <- index_item_filtered %>% filter(题目列名 == item_value) %>% slice(1)
                        if (nrow(item_row) > 0) {
                            options_str <- item_row$选项
                            if (!is.na(options_str) && options_str != "") {
                                # 用//C//分割
                                categories <- strsplit(options_str, "//C//", fixed = TRUE)[[1]]
                                categories <- trimws(categories)
                            }
                        }
                    }
                }
            } else if (dim_or_item == "basic") {
                # 从数据中直接获取类别，按照dat[[对应数据列]]的levels顺序
                if (!is.null(dat)) {
                    basic_col <- row$报告维度
                    if (!is.na(basic_col) && basic_col != "" && basic_col %in% colnames(dat)) {
                        # 判断当前变量是否为factor
                        if (is.factor(dat[[basic_col]])) {
                            categories <- levels(dat[[basic_col]])
                        } else {
                            categories <- unique(dat[[basic_col]])
                            categories <- categories[!is.na(categories)]
                            categories <- as.character(categories)
                        }
                    }
                }
            }
            
            # 如果从上述方法获取失败，从table_data中获取
            if (length(categories) == 0) {
                categories <- table_data$类别
                categories <- as.character(categories)
            }
            
            # 按照categories的顺序，从table_data中获取对应的占比
            # 处理table_data中的类别名称：去除换行符以便匹配
            table_data$类别_标准化 <- gsub("\n", "", table_data$类别, fixed = TRUE)
            table_data$类别_标准化 <- trimws(table_data$类别_标准化)
            
            pcts <- numeric(length(categories))
            for (i in seq_along(categories)) {
                # 标准化类别名称用于匹配
                cat_normalized <- trimws(categories[i])
                cat_data <- table_data[table_data$类别_标准化 == cat_normalized, ]
                if (nrow(cat_data) > 0) {
                    pcts[i] <- round(cat_data$占比[1], 1)
                } else {
                    pcts[i] <- 0
                }
            }
            
            # 组合文本：类别1（占比1%）；类别2（占比2%）；...
            text_parts <- paste0(categories, "（", pcts, "%）")
            text <- paste(text_parts, collapse = "；")
            text <- paste0(text, "。")
            
            # 添加开头语："在" + 图题表题 + "上，选择情况为："
            title <- ifelse(is.na(row$图题表题) || row$图题表题 == "", "", row$图题表题)
            if (title != "") {
                text <- paste0("在", title, "上，选择情况为：", text)
            }
            
            return(text)
            
        } else {
            # 情况2：sum_indices != "all"，参考stack_bar_var_distribution的逻辑
            # 解析sum_indices字符串
            # 如果包含&，则分割；否则作为单个数字
            if (grepl("&", sum_indices_str, fixed = TRUE)) {
                # 多个数字，用&分隔，如 "2&3"
                sum_indices <- as.numeric(strsplit(sum_indices_str, "&", fixed = TRUE)[[1]])
            } else {
                # 单个数字，如 "1"
                sum_indices <- as.numeric(sum_indices_str)
            }
            
            # 检查解析结果是否有效
            if (any(is.na(sum_indices)) || length(sum_indices) == 0) {
                return(NULL)
            }
            
            # 提取类别名称，按照正确的顺序
            categories <- c()
            
            if (dim_or_item == "dim") {
                # 从index_item中获取报告维度分类名
                if (is.null(index_item)) {
                    # 如果index_item不可用，从table_data中获取
                    categories <- table_data$类别
                    categories <- as.character(categories)
                } else {
                    dim_value <- row$报告维度
                    if (!is.na(dim_value) && dim_value != "") {
                        # 根据数据表对应过滤index_item
                        index_item_filtered <- filter_index_item_by_data_table(index_item, row)
                        
                        # 先尝试报告维度匹配
                        item_row <- index_item_filtered %>% filter(报告维度 == dim_value) %>% slice(1)
                        if (nrow(item_row) == 0) {
                            # 如果失败，尝试子维度匹配
                            item_row <- index_item_filtered %>% filter(子维度 == dim_value) %>% slice(1)
                        }
                        
                        if (nrow(item_row) > 0) {
                            # 获取报告维度分类名1到10
                            for (j in 1:10) {
                                col_name <- paste0("报告维度分类名", j)
                                if (col_name %in% colnames(index_item_filtered)) {
                                    cat_val <- item_row[[col_name]]
                                    if (!is.na(cat_val) && cat_val != "") {
                                        categories <- c(categories, as.character(cat_val))
                                    }
                                }
                            }
                        }
                    }
                    # 如果从index_item中获取失败，从table_data中获取
                    if (length(categories) == 0) {
                        categories <- table_data$类别
                        categories <- as.character(categories)
                    }
                }
            } else if (dim_or_item == "item") {
                # 从index_item中获取选项列
                if (is.null(index_item)) {
                    # 如果index_item不可用，从table_data中获取
                    categories <- table_data$类别
                    categories <- as.character(categories)
                } else {
                    item_value <- row$报告维度
                    if (!is.na(item_value) && item_value != "") {
                        # 根据数据表对应过滤index_item
                        index_item_filtered <- filter_index_item_by_data_table(index_item, row)
                        
                        item_row <- index_item_filtered %>% filter(题目列名 == item_value) %>% slice(1)
                        if (nrow(item_row) > 0) {
                            options_str <- item_row$选项
                            if (!is.na(options_str) && options_str != "") {
                                # 用//C//分割
                                categories <- strsplit(options_str, "//C//", fixed = TRUE)[[1]]
                                categories <- trimws(categories)
                            }
                        }
                    }
                    # 如果从index_item中获取失败，从table_data中获取
                    if (length(categories) == 0) {
                        categories <- table_data$类别
                        categories <- as.character(categories)
                    }
                }
            } else if (dim_or_item == "basic") {
                # 从数据中直接获取类别，按照dat[[对应数据列]]的levels顺序
                if (is.null(dat)) {
                    # 如果dat不可用，从table_data中获取
                    categories <- table_data$类别
                    categories <- as.character(categories)
                } else {
                    # 确定对应的数据列
                    basic_col <- row$报告维度
                    if (!is.na(basic_col) && basic_col != "" && basic_col %in% colnames(dat)) {
                        # 判断当前变量是否为factor
                        if (is.factor(dat[[basic_col]])) {
                            categories <- levels(dat[[basic_col]])
                        } else {
                            categories <- unique(dat[[basic_col]])
                            categories <- categories[!is.na(categories)]
                            categories <- as.character(categories)
                        }
                    } else {
                        # 如果找不到对应的列，从table_data中获取
                        categories <- table_data$类别
                        categories <- as.character(categories)
                    }
                }
            }
            
            if (length(categories) == 0) {
                return(NULL)
            }
            
            # 检查sum_indices是否有效
            valid_indices <- sum_indices[sum_indices >= 1 & sum_indices <= length(categories)]
            if (length(valid_indices) == 0) {
                return(NULL)
            }
            
            # 获取需要汇报的类别名称
            class <- categories[valid_indices]
            
            # 对于pie_distribution和pie_distribution_trans_bar，多个数字时分别汇报每个类别的占比
            if (length(valid_indices) > 1) {
                # 多个类别：分别汇报每个类别的占比
                # 处理table_data中的类别名称：去除换行符以便匹配
                table_data$类别_标准化 <- gsub("\n", "", table_data$类别, fixed = TRUE)
                table_data$类别_标准化 <- trimws(table_data$类别_标准化)
                
                # 标准化class中的类别名称用于匹配
                class_normalized <- trimws(class)
                selected_data <- table_data[table_data$类别_标准化 %in% class_normalized, ]
                if (nrow(selected_data) == 0) {
                    return(NULL)
                }
                
                # 按照valid_indices的顺序获取类别和占比
                text_parts <- c()
                for (idx in valid_indices) {
                    cat_name <- categories[idx]
                    cat_normalized <- trimws(cat_name)
                    cat_data <- selected_data[selected_data$类别_标准化 == cat_normalized, ]
                    if (nrow(cat_data) > 0) {
                        pct <- round(cat_data$占比[1], 1)
                        text_parts <- c(text_parts, paste0(cat_name, "（", pct, "%）"))
                    }
                }
                
                if (length(text_parts) == 0) {
                    return(NULL)
                }
                
                # 组合文本：类别1（占比1%）；类别2（占比2%）；...
                text <- paste(text_parts, collapse = "；")
                text <- paste0(text, "。")
                
                # 添加开头语："在" + 图题表题 + "上，选择情况为："
                title <- ifelse(is.na(row$图题表题) || row$图题表题 == "", "", row$图题表题)
                if (title != "") {
                    text <- paste0("在", title, "上，选择情况为：", text)
                }
                
                return(text)
            } else {
                # 单个类别：汇报该类别的占比
                class_text <- class[1]
                # 处理table_data中的类别名称：去除换行符以便匹配
                table_data$类别_标准化 <- gsub("\n", "", table_data$类别, fixed = TRUE)
                table_data$类别_标准化 <- trimws(table_data$类别_标准化)
                
                # 标准化class中的类别名称用于匹配
                class_normalized <- trimws(class)
                selected_data <- table_data[table_data$类别_标准化 %in% class_normalized, ]
                if (nrow(selected_data) == 0) {
                    return(NULL)
                }
                pct_sum <- round(sum(selected_data$占比, na.rm = TRUE), 1)
                
                # 生成文本（参考stack_bar_var_distribution的逻辑）
                if (dim_or_item == "dim") {
                    dim_name <- row$报告维度
                    text <- paste0("在", dim_name, "上，", pct_sum, "%的", role, "达到", class_text, "的水平。")
                } else if (dim_or_item == "item") {
                    title <- ifelse(is.na(row$图题表题) || row$图题表题 == "", "", row$图题表题)
                    title <- gsub("情况对比|基本情况|情况|各区市", "", title)
                    text <- paste0("在", title, "上，", pct_sum, "%的", role, "选择了", class_text, "。")
                } else {
                    # basic类型，使用报告维度
                    dim_name <- row$报告维度
                    text <- paste0("在", dim_name, "上，", pct_sum, "%的", role, "达到", class_text, "的水平。")
                }
                
                return(text)
            }
        }
    } else if (chart_type == "table_items_score") {
        # table_items_score的文本生成：先呈现平均分，再找到得分最高的2个题目和最低的1个题目
        if (is.null(chart_obj) || !is.data.frame(chart_obj) || nrow(chart_obj) == 0) {
            return(NULL)
        }
        
        # 检查必要的列
        if (!"题目" %in% colnames(chart_obj) || !"平均分" %in% colnames(chart_obj)) {
            return(NULL)
        }
        
        # 排除"维度均分"行
        table_data <- chart_obj[chart_obj$题目 != "维度均分", ]
        if (nrow(table_data) == 0) {
            return(NULL)
        }
        
        # 获取维度均分（从属性或表格中）
        dim_mean_score <- attr(chart_obj, "dim_mean_score")
        if (is.null(dim_mean_score)) {
            # 如果属性中没有，从表格中查找
            dim_mean_row <- chart_obj[chart_obj$题目 == "维度均分", ]
            if (nrow(dim_mean_row) > 0) {
                dim_mean_score <- dim_mean_row$平均分[1]
            } else {
                # 如果表格中也没有，计算平均值
                dim_mean_score <- mean(table_data$平均分, na.rm = TRUE)
            }
        }
        dim_mean_score <- round(dim_mean_score, 2)
        
        # 获取报告维度名称
        dim_name <- ifelse(is.na(row$报告维度) || row$报告维度 == "", "该维度", row$报告维度)
        
        # 找到得分最高的2个题目（处理多个相等的情况）
        max_scores <- sort(unique(table_data$平均分), decreasing = TRUE)
        top_items <- c()
        for (score in max_scores) {
            items_with_score <- table_data[table_data$平均分 == score, ]
            top_items <- c(top_items, items_with_score$题目)
            if (length(top_items) >= 2) {
                break
            }
        }
        # 只取前2个
        top_items <- head(top_items, 2)
        
        # 找到得分最低的1个题目（处理多个相等的情况）
        min_scores <- sort(unique(table_data$平均分), decreasing = FALSE)
        bottom_items <- c()
        for (score in min_scores) {
            items_with_score <- table_data[table_data$平均分 == score, ]
            bottom_items <- c(bottom_items, items_with_score$题目)
            if (length(bottom_items) >= 1) {
                break
            }
        }
        # 只取第1个
        bottom_item <- head(bottom_items, 1)
        
        # 构建文本
        text_parts <- c()
        
        # 第一部分：平均分
        text_parts <- c(text_parts, paste0(dim_name, "的平均得分为", dim_mean_score))
        
        # 第二部分：得分最高的2项
        if (length(top_items) > 0) {
            if (length(top_items) == 1) {
                text_parts <- c(text_parts, paste0("得分最高的1项为：", top_items[1]))
            } else {
                text_parts <- c(text_parts, paste0("得分最高的2项为：", top_items[1], "、", top_items[2]))
            }
        }
        
        # 第三部分：得分最低的1项
        if (length(bottom_item) > 0) {
            text_parts <- c(text_parts, paste0("得分最低的题目为：", bottom_item[1]))
        }
        
        # 组合文本，用分号分隔，最后用句号结尾
        text <- paste(text_parts, collapse = "；")
        text <- paste0(text, "。")
        
        return(text)
    } else if (chart_type == "simple_bar_items_score") {
        tbl <- if (is.list(chart_obj) && !is.data.frame(chart_obj) && !is.null(chart_obj$table)) chart_obj$table else NULL
        if (is.null(tbl) || !is.data.frame(tbl) || nrow(tbl) == 0) {
            return(NULL)
        }
        if (!"平均分" %in% colnames(tbl)) {
            return(NULL)
        }
        dim_name <- ifelse(is.na(row$报告维度) || row$报告维度 == "", "该维度", row$报告维度)
        grand <- attr(tbl, "dim_all_items_person_mean")
        if (is.null(grand) || is.na(grand)) {
            grand <- mean(tbl$平均分, na.rm = TRUE)
        }
        num_str <- formatC(round(as.numeric(grand), 2), format = "f", digits = 2)
        paste0(dim_name, "的平均值是", num_str, "。")
    } else if (chart_type == "table_cnt_stu") {
        # table_cnt_stu的文本生成：汇报总体样本量
        if (is.null(dat) || !is.data.frame(dat) || nrow(dat) == 0) {
            return(NULL)
        }
        
        # 计算样本量
        sample_size <- nrow(dat)
        
        # 生成文本
        text <- paste0("本区（市）共回收有效问卷", sample_size, "份，有效参测比例约为100%。样本分布情况如下。")
        
        return(text)
    }
    
    return(NULL)
}
