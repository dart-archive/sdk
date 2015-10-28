#!/bin/bash

function usage {
  echo "Usage: $0 [--fletch <fletch binary directory>] <elf-file>"
  echo "         <snapshot-file> <symbol-name>"
  echo
  echo "This will generate an object file <symbol-name> that can be linked"
  echo "against the original <elf-file> and adds the following symbols:"
  echo
  echo "  __fletch__<symbol-name>_heap_start"
  echo "  __fletch__<symbol-name>_heap_end"
  echo "  __fletch__<symbol-name>_heap_size"
  echo
  echo "for the program heap."
  echo
  echo "The generated output file will be named <symbol-name.o>."
}

if [ $# -lt 3 ]; then
  usage
  exit 1
fi

while [ $# -gt 3 ]; do
  case $1 in
    --fletch | -f)
      FLETCHHOME="$2/"
      shift 2
      ;;
    --help | -h)
      usage
      exit 1
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [ ! -e $1 ]; then
  echo "Cannot find linked elf file `$1` to embed into..."
  exit 1
fi

if [ ! -e $2 ]; then
  echo "Cannot find snapshot file `$2` to embed..."
  exit 1
fi

if [ ! -e "${FLETCHHOME}flashtool" ]; then
  echo "Cannot find flashtool relocator. Use --fletch to set fletch path..."
  exit 1
fi

SNAPSHOT=$(objdump -h $1 | grep '[0-9][0-9]* \.snapshot')

if [ -z "$SNAPSHOT" ]; then
  echo "The elf file does not contain a .snapshot section. Add the following"
  echo "lines to the flash section of your linker script:                   "
  echo
  echo ".snapshot ALIGN(4096) :"
  echo "{                                                                   "
  echo "    __fletch_program_heap_start = .;                                "
  echo "    KEEP(*(.snapshot))                                              "
  echo "    __fletch_program_heap_end = .;                                  "
  echo "}                                                                   "
  exit 1
fi

PARTS=($SNAPSHOT)
ADDRESS=0x${PARTS[3]}
echo "Found .snapshot section at $ADDRESS..."

TEMPDIR=$(mktemp -d fletchflash.XXX)
mkdir ${TEMPDIR}/fletch

echo "Generating output in $TEMPDIR..."

${FLETCHHOME}flashtool $2 ${ADDRESS} ${TEMPDIR}/fletch/programheap.bin ${TEMPDIR}/fletch/program.bin

(cd ${TEMPDIR}; arm-none-eabi-objcopy --rename-section .data=.snapshot --redefine-sym _binary_fletch_programheap_bin_start=__fletch_${3}_heap_start --redefine-sym _binary_fletch_programheap_bin_end=__fletch_${3}_heap_end --redefine-sym _binary_fletch_programheap_bin_size=__fletch_${3}_heap_size -I binary -B armv4t -O elf32-littlearm fletch/programheap.bin fletch/programheap.o)

arm-none-eabi-ld -r ${TEMPDIR}/fletch/programheap.o -o ${3}.o

(cd ${TEMPDIR}; rm fletch/*; rmdir fletch)
rmdir ${TEMPDIR}

echo "Written output to ${3}.o..."
