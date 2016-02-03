SECTIONS {
	.snapshot ALIGN(4096) :
	{
		__dartino_program_heap_start = .;
		KEEP(*(.snapshot))
		__dartino_program_heap_end = .;
	}
}
INSERT BEFORE .rodata;
