
void assemble_code  (VOID);
void initialize_assembler (FILE *file);
void define_local_label (int id,int flag);
void define_external_label (int id,int flag,char label_name[]);
void store_word_in_data_section (UWORD i);
void store_long_word_in_data_section (ULONG i);
void store_label_in_data_section (int label_id);
void store_label_offset_in_data_section (int label_id);
void store_descriptor_in_data_section (int label_id);
void store_descriptor_in_code_section (int label_id);
void store_c_string_in_data_section (char *string,int length);
void store_abc_string_in_data_section (char *string,int length);
void store_c_string_in_code_section (char *string,int length);
void store_abc_string_in_code_section (char *string,int length);
void store_descriptor_string_in_code_section (char *string,int length,int string_code_label_id,LABEL *string_label);
void store_label_offset_in_code_section (int label_id);
void start_new_module (int flag);

#ifndef GNU_C
void write_version_and_options (int version,int options);
void write_depend (char *module_name);
#endif
