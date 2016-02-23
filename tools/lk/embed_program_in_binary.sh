#!/bin/bash

set -e

TEMPDIR=$(mktemp -d dartinoflash.XXX)
mkdir ${TEMPDIR}/dartino

function cleanup() {
  rm -rf ${TEMPDIR}
}

trap cleanup EXIT INT TERM

function usage {
  echo "Usage: $0 [--dartino <dartino binary directory>] <elf-file>"
  echo "         <snapshot-file> <symbol-name>"
  echo
  echo "This will generate an object file <symbol-name> that can be linked"
  echo "against the original <elf-file> and adds the following symbols:"
  echo
  echo "  __dartino__<symbol-name>_heap_start"
  echo "  __dartino__<symbol-name>_heap_end"
  echo "  __dartino__<symbol-name>_heap_size"
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
    --dartino | -f)
      DARTINOHOME="$2/"
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

if [ ! -e "${DARTINOHOME}flashtool" ]; then
  echo "Cannot find flashtool relocator. Use --dartino to set dartino path..."
  exit 1
fi

SNAPSHOT=$(objdump -h $1 | grep '[0-9][0-9]* \.snapshot')

if [ -z "$SNAPSHOT" ]; then
  echo "The elf file does not contain a .snapshot section. Add the following"
  echo "lines to the flash section of your linker script:                   "
  echo
  echo ".snapshot ALIGN(4096) :"
  echo "{                                                                   "
  echo "    __dartino_program_heap_start = .;                                "
  echo "    KEEP(*(.snapshot))                                              "
  echo "    __dartino_program_heap_end = .;                                  "
  echo "}                                                                   "
  exit 1
fi

INTRINSICS=$(objdump -t $1 | grep -o -E '^[[:xdigit:]]+ .* Intrinsic_([[:alpha:]])+$' | sed -e 's/^\([[:xdigit:]]*\) .* Intrinsic_\([[:alpha:]]*\)$/-i \2=0x\1/g')

ENTRY_ADDRESS=$(objdump -t $1 | grep -o -E '^[[:xdigit:]]+ .* InterpreterMethodEntry$' | sed -e 's/^\([[:xdigit:]]*\) .* InterpreterMethodEntry$/0x\1/g')

PARTS=($SNAPSHOT)
ADDRESS=0x${PARTS[3]}
echo "Found .snapshot section at $ADDRESS..."

echo "Generating output in $TEMPDIR..."

FLASHTOOLCMD="${DARTINOHOME}flashtool $INTRINSICS $ENTRY_ADDRESS $2 ${ADDRESS} ${TEMPDIR}/dartino/programheap.bin"
$FLASHTOOLCMD

(cd ${TEMPDIR}; arm-none-eabi-objcopy --rename-section .data=.snapshot --redefine-sym _binary_dartino_programheap_bin_start=__dartino_${3}_heap_start --redefine-sym _binary_dartino_programheap_bin_end=__dartino_${3}_heap_end --redefine-sym _binary_dartino_programheap_bin_size=__dartino_${3}_heap_size -I binary -B armv4t -O elf32-littlearm dartino/programheap.bin dartino/programheap.o)

arm-none-eabi-ld -r ${TEMPDIR}/dartino/programheap.o -o ${3}.o

echo "Written output to ${3}.o..."

trap - EXIT INT TERM

cleanup
