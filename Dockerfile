## Warning!!!!!!!!!!!!!!!!!!!!!
## This Dockerfile will create at least 14GB image for now

FROM ubuntu:jammy-20240627.1 AS builder

WORKDIR /winterjs

SHELL [ "bash", "-c" ]

RUN sed -i s/archive\.ubuntu\.com/mirrors\.byr\.team/g /etc/apt/sources.list

RUN apt-get update && \
    apt-get install -y unzip git curl

## install rust

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y && \
    source $HOME/.cargo/env && \
    rustup toolchain install 1.76 && \
    rustup default 1.76

ENV PATH="/root/.local/share/fnm:/root/.cargo/bin:${PATH}"

## install node

RUN curl -fsSL https://fnm.vercel.app/install | bash

RUN eval "$(fnm env)" && fnm install 16 && fnm default 16

## Setup Wasmer

RUN git clone https://github.com/wasmerio/setup-wasmer.git && \
    cd setup-wasmer && \
    eval "$(fnm env)" && node dist/index.js

## Download wasix-libc && Unpack wasix-libc

RUN mkdir sysroot && curl -L https://github.com/wasix-org/rust/releases/download/v2024-09-12.1/wasix-libc.tar.gz -o sysroot/wasix-libc.tar.gz && \
    cd sysroot && \
    tar -xvf wasix-libc.tar.gz

## Download wasix toolchain && Install wasix toolchain

RUN mkdir wasix-rust-toolchain && curl -L https://github.com/wasix-org/rust/releases/download/v2024-09-12.1/rust-toolchain-x86_64-unknown-linux-gnu.tar.gz -o wasix-rust-toolchain/toolchain.tar.gz && \
    cd wasix-rust-toolchain && \
    tar -xvf toolchain.tar.gz && \
    chmod +x bin/*                 && \
    chmod +x lib/rustlib/*/bin/*       && \
    chmod +x lib/rustlib/*/bin/gcc-ld/* && \
    rustup toolchain link wasix .


# current workdir is /winterjs
ENV WASI_SYSROOT=/winterjs/sysroot/wasix-libc/sysroot32


RUN apt-get install -y build-essential python3.11 python3-distutils llvm-15 libclang-dev clang-15 wabt pkgconf m4 zlib1g-dev python3-pip lld-15
RUN eval "$(fnm env)" && npm i -g wasm-opt pnpm concurrently

## clone winterjs

COPY . .

# RUN build.sh

RUN ln -s /usr/bin/clang-15 /usr/bin/clang && \
    ln -s /usr/bin/clang++-15 /usr/bin/clang++ && \
    ln -s /usr/bin/llvm-ar-15 /usr/bin/llvm-ar && \
    ln -s /usr/bin/llvm-nm-15 /usr/bin/llvm-nm && \
    ln -s /usr/bin/llvm-ranlib-15 /usr/bin/llvm-ranlib && \
    ln -s /usr/bin/llvm-objdump-15 /usr/bin/llvm-objdump

RUN eval "$(fnm env)" && bash build.sh
RUN cargo build --profile release-compact

ENTRYPOINT ["/bin/bash"]