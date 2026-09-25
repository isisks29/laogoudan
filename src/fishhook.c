// Copyright (c) 2013, Facebook, Inc.
// All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//   * Redistributions of source code must retain the above copyright
//     notice, this list of conditions and the following disclaimer.
//   * Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//   * Neither the name of Facebook nor the
//     names of its contributors may be used to endorse or promote products
//     derived from this software without specific prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL FACEBOOK BE LIABLE FOR ANY DIRECT,
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#include "fishhook.h"

#include <dlfcn.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>

#ifdef __LP64__
typedef struct mach_header_64 mach_header_t;
typedef struct segment_command_64 segment_command_t;
typedef struct section_64 section_t;
typedef struct nlist_64 nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT_64
#else
typedef struct mach_header mach_header_t;
typedef struct segment_command segment_command_t;
typedef struct section section_t;
typedef struct nlist nlist_t;
#define LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT
#endif

#ifndef seglinkedit
#define seglinkedit __linkedit
#endif

typedef nlist_t symtab_entry_t;

struct rebindings_entry {
    struct rebinding *rebindings;
    size_t rebindings_nel;
    struct rebindings_entry *next;
};

static struct rebindings_entry *rebindings_head = NULL;

static int rebind_symbols_for_image(struct rebindings_entry *rebindings,
                                     size_t rebindings_nel,
                                     void *header,
                                     intptr_t header_size) {
    mach_header_t *hdr = (mach_header_t *)header;
    
    uintptr_t cur = (uintptr_t)hdr + sizeof(mach_header_t);
    uintptr_t cmd_end = (uintptr_t)hdr + hdr->sizeofcmds;
    
    struct segment_command *linkedit_segment = NULL;
    
    for (struct load_command *cmd = (struct load_command *)cur;
         (uintptr_t)cmd < cmd_end;
         cmd = (struct load_command *)((uintptr_t)cmd + cmd->cmdsize)) {
        
        switch (cmd->cmd) {
            case LC_SEGMENT:
            case LC_SEGMENT_64: {
                struct segment_command *seg = (struct segment_command *)cmd;
                if (strcmp(seg->segname, "__LINKEDIT") == 0) {
                    linkedit_segment = seg;
                }
                break;
            }
        }
    }
    
    if (!linkedit_segment) return -1;
    
    uintptr_t cur2 = (uintptr_t)hdr + sizeof(mach_header_t);
    uintptr_t cmd_end2 = (uintptr_t)hdr + hdr->sizeofcmds;
    
    struct symtab_command *symtab_cmd = NULL;
    
    for (struct load_command *cmd = (struct load_command *)cur2;
         (uintptr_t)cmd < cmd_end2;
         cmd = (struct load_command *)((uintptr_t)cmd + cmd->cmdsize)) {
        
        switch (cmd->cmd) {
            case LC_SYMTAB:
                symtab_cmd = (struct symtab_command *)cmd;
                break;
        }
    }
    
    if (!symtab_cmd) return -1;
    
    uintptr_t linkedit_base = (uintptr_t)hdr - linkedit_segment->vmaddr + linkedit_segment->fileoff;
    nlist_t *symtab = (nlist_t *)(linkedit_base + symtab_cmd->symoff);
    char *strtab = (char *)(linkedit_base + symtab_cmd->stroff);
    
    uint32_t nsyms = symtab_cmd->nsyms;
    
    for (size_t i = 0; i < rebindings_nel; i++) {
        const char *name = rebindings[i].name;
        if (!name) continue;
        
        for (uint32_t j = 0; j < nsyms; j++) {
            if (symtab[j].n_un.n_strx == 0) continue;
            
            char *sym_name = strtab + symtab[j].n_un.n_strx;
            if (strcmp(sym_name, name) == 0) {
                void **slot = (void **)((uintptr_t)hdr + symtab[j].n_value);
                
                if (rebindings[i].replaced != NULL) {
                    *rebindings[i].replaced = *slot;
                }
                
                *slot = rebindings[i].replacement;
                break;
            }
        }
    }
    
    return 0;
}

int rebind_symbols(struct rebinding rebindings[], size_t rebindings_nel) {
    mach_header_t *header = NULL;
    
    uint32_t count = _dyld_image_count();
    if (count > 0) {
        header = (mach_header_t *)_dyld_get_image_header(0);
    }
    
    if (!header) {
        Dl_info info;
        if (dladdr((void *)rebind_symbols, &info) && info.dli_fbase) {
            header = (mach_header_t *)info.dli_fbase;
        } else {
            return -1;
        }
    }
    
    return rebind_symbols_for_image(NULL, rebindings_nel, header, 0);
}

int rebind_symbols_image(void *header,
                          intptr_t header_size,
                          struct mach_header *mhdr,
                          struct rebinding rebindings[],
                          size_t rebindings_nel) {
    if (!header || !mhdr) return -1;
    
    return rebind_symbols_for_image(NULL, rebindings_nel, header, header_size);
}
