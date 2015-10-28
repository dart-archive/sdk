SECTIONS {
	.snapshot ALIGN(4096) :
	{
		__fletch_program_heap_start = .;
		KEEP(*(.snapshot))
		__fletch_program_heap_end = .;
	}
}
INSERT BEFORE .rodata;
