
void assemble_code  (VOID);
void initialize_assembler (FILE *file);
void define_local_label (int id,int flag);
void define_external_label (int id,int flag,char label_name[]);
void store_word_in_data_section (UWORD i);
void store_long_word_in_data_section (unsigned int i);
void define_data_label (LABEL *label);
void define_exported_data_label_with_offset (LABEL *label,int offset);
void store_label_in_data_section (LABEL *label);
void store_label_offset_in_data_section (LABEL *label);
void store_descriptor_in_data_section (LABEL *label);
void store_descriptor_in_code_section (int label_id);
void store_c_string_in_data_section (char *string,int length);
void store_abc_string_in_data_section (char *string,int length);
void store_abc_string4_in_data_section (char *string,int length);
void store_c_string_in_code_section (char *string,int length);
void store_abc_string_in_code_section (char *string,int length);
void store_descriptor_string_in_code_section (char *string,int length,int string_code_label_id,LABEL *string_label);
void store_label_offset_in_code_section (int label_id);
void start_new_module (int flag);
void store_descriptor_string_in_data_section (char *string,int length,LABEL *string_label);
void store_word64_in_data_section (int_64 c);
void store_2_words_in_data_section (UWORD w1,UWORD w2);
void as_new_data_module (void);

#ifndef GNU_C
void write_version_and_options (int version,int options);
void write_depend (char *module_name);
#endif

struct ms {	long m; int s; };

extern struct ms magic (long d);
