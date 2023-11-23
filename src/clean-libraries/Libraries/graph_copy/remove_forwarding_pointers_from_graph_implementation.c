Int **stack_p;

stack_p = stack_end;

for (;;){
	for (;;){
		Int forwarding_pointer,desc;
		
		forwarding_pointer=*node_p;
		if ((forwarding_pointer & 1)==0)
			break;

#ifdef USE_DESC_RELATIVE_TO_ARRAY
		desc = (Int)&__ARRAY__ + *((Int*)(forwarding_pointer-1));
#else
		desc = *((Int*)(forwarding_pointer-1));
#endif
		*node_p=desc;
		
		if (desc & 2){
			unsigned Int arity;
				
			arity=((unsigned short *)desc)[-1];
			if (arity==0){
				if (desc!=(Int)&__ARRAY__+2){
					break;
				} else {
					Int elem_desc;

					elem_desc=node_p[2];

					if (elem_desc==0){
						Int array_size;
						
						array_size=node_p[1];
						node_p+=3;
						
						stack_p-=array_size;
						
						while (--array_size>=0)
							stack_p[array_size]=(Int*)node_p[array_size];						
						break;
					} else if (elem_desc==(Int)&INT+2 || elem_desc==(Int)&REAL+2 || elem_desc==(Int)&BOOL+2){
						break;
					} else {
						Int n_field_pointers;
						
						n_field_pointers=*(unsigned short *)elem_desc;

						if (n_field_pointers!=0){
							Int field_size,array_size;
							
							field_size=((unsigned short *)elem_desc)[-1]-(Int)256;

							array_size=node_p[1];
							node_p+=3;
					
							if (n_field_pointers==field_size){
								array_size*=field_size;

								stack_p-=array_size;
								
								while (--array_size>=0)
									stack_p[array_size]=(Int*)node_p[array_size];						
							} else {
								Int n_array_pointers,i,*pointer_p;
								
								n_array_pointers=n_field_pointers*array_size;
								
								stack_p-=n_array_pointers;
								
								pointer_p=(Int*)stack_p;
								
								for (i=0; i<array_size; ++i){
									copy (pointer_p,node_p,n_field_pointers);
									pointer_p+=n_field_pointers;
									node_p+=field_size;
								}
							}
						}
						break;
					}						
				}
			} else if (arity==1){
				node_p=(Int*)node_p[1];
				continue;
			} else if (arity==2){
				*--stack_p=(Int*)node_p[2];
			
				node_p=(Int*)node_p[1];
				continue;
			} else if (arity<256){
				Int **args,n_words;

				args=(Int**)node_p[2];
				n_words=arity-1;
				
				stack_p-=n_words;
				
				--n_words;
				stack_p[n_words]=args[n_words];
				while (--n_words>=0)
					stack_p[n_words]=args[n_words];

				node_p=(Int*)node_p[1];
				continue;					
			} else {
				Int n_pointers;
				
				n_pointers=*(unsigned short*)desc;
				if (n_pointers==0)
					break;
				else {
					if (n_pointers>=2){
						if (n_pointers==2){
							arity-=256;
							if (arity==2){
								*--stack_p=(Int*)node_p[2];									
							} else {
								Int **args;

								args=(Int**)node_p[2];
								*--stack_p=args[0];									
							}
						} else {
							Int **args,n_words;

							args=(Int**)node_p[2];
							n_words=n_pointers-1;
							
							stack_p-=n_words;
							
							--n_words;
							stack_p[n_words]=args[n_words];
							while (--n_words>=0)
								stack_p[n_words]=args[n_words];

						}
					}
					node_p=(Int*)node_p[1];
					continue;
				}
			}
		} else {
			Int arity;

			arity=((int*)desc)[-1];
#ifdef PROFILE_GRAPH
			if (arity>0)
				arity-=257;
#endif

			if (arity>1){
				if (arity<256){
					Int **args,n_words;
	
					args=(Int**)&node_p[2];
					n_words=arity-1;
					
					stack_p-=n_words;
					
					--n_words;
					stack_p[n_words]=args[n_words];
					while (--n_words>=0)
						stack_p[n_words]=args[n_words];
					
					node_p=(Int*)node_p[1];
					continue;
				} else {
					Int n_pointers,n_non_pointers;
					
					n_non_pointers=arity>>8;
					n_pointers=(arity & 255) - n_non_pointers;
											
					if (n_pointers==0)
						break;
					else {
						if (n_pointers>1){
							Int **args;
							
							args=(Int**)&node_p[2];
							--n_pointers;
							
							stack_p-=n_pointers;
							
							--n_pointers;
							stack_p[n_pointers]=args[n_pointers];
							while (--n_pointers>=0)
								stack_p[n_pointers]=args[n_pointers];
						}
						node_p=(Int*)node_p[1];
						continue;
					}						
				}
			} else if (arity==0){
				break;
			} else {
				node_p=(Int*)node_p[1];
				continue;
			}
		}
	}

	if (stack_p==stack_end)
		return;
	
	node_p=*stack_p++;
}	
