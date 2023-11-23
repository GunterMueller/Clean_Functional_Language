
extern void assemble_code (VOID);
extern void initialize_assembler (FILE *file);
extern void define_data_label (LABEL *label);
extern void store_2_words_in_data_section (UWORD w1,UWORD w2);
extern void store_long_word_in_data_section (ULONG i);
extern void store_label_in_data_section (LABEL *label);
extern void store_descriptor_in_data_section (LABEL *label);
extern void store_c_string_in_data_section (char *string,int length);
extern void store_abc_string_in_data_section (char *string,int length);
extern void store_descriptor_string_in_data_section (char *string,int length,LABEL *string_label);

extern void as_new_data_module (void);
extern void w_as_new_data_module (void);
