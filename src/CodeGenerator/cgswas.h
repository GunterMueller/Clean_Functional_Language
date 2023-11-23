void initialize_write_assembly (FILE *ass_file);
void write_assembly (VOID);
void w_as_c_string_in_data_section (char *string,int length);
void w_as_abc_string_in_data_section (char *string,int length);
void w_as_c_string_in_code_section (char *string,int length,int label_number);
void w_as_abc_string_in_code_section (char *string,int length,int label_number);
void w_as_descriptor_string_in_code_section
	(char *string,int length,int string_label_id,LABEL *string_label);
void w_as_word_in_data_section (int n);
void w_as_label_in_data_section (char *label_name);
void w_as_define_label (LABEL *label);
