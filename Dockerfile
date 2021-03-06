FROM centos:centos7

ARG BUILD_DATE
ARG VCS_REF

ARG NEOVIM_VERSION=0.4.3
ARG BEAR_VERSION=2.4.3
ARG FD_VERSION=7.5.0
ARG FPP_VERSION=0.9.2

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-url="https://github.com/thawk/docker-spacevim-base.git" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.schema-version="1.0.0-rc1"

ENV HOME=/myhome
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN mkdir -p $HOME
RUN mkdir -p $HOME/localbin

COPY wandisco-svn.repo /etc/yum.repos.d/wandisco-svn.repo

RUN yum install -y \
    https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
    centos-release-scl-rh \
    https://repo.ius.io/ius-release-el7.rpm \
 && yum install -y \
    python2-pip \
    python3 \
    python3-pip \
    lua \
    make \
    libtool \
    autoconf \
    automake \
    cmake3 \
    gcc-c++ \
    the_silver_searcher \
    git \
    subversion \
    man \
    wget \
    which \
    fasd \
    tmux2 \
 && yum clean all

RUN pip2 install --upgrade pip \
 && pip3 install --upgrade pip \
 && pip2 install \
    pynvim \
 && pip3 install \
    msgpack \
    pynvim \
    jedi \
    flake8 \
    flake8-docstrings \
    flake8-isort \
    flake8-quotes \
 && true

RUN true \
 && cd $HOME \
 && (curl -sL https://rpm.nodesource.com/setup_10.x | bash -) \
 && (curl --silent --location https://dl.yarnpkg.com/rpm/yarn.repo > /etc/yum.repos.d/yarn.repo) \
 && yum install -y nodejs yarn \
 && npm install -g \
    neovim \
 && yum clean all

#### Install Bear to support C-family semantic completion ####
ARG BEAR_SRC=${HOME}/Bear-${BEAR_VERSION}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# See how to do an out of source build
#   https://stackoverflow.com/a/20611964
#   https://stackoverflow.com/a/24435795
RUN curl -fsSL https://codeload.github.com/rizsotto/Bear/tar.gz/"${BEAR_VERSION}" | tar -xz -C "${HOME}" \
    && cmake3 -B"${BEAR_SRC}" -H"${BEAR_SRC}" \
    && make -C "${BEAR_SRC}" install \
    && rm -rf "${BEAR_SRC}"

#### Install neovim ####
RUN true \
 && cd $HOME \
 && umask 0000 \
 && (curl -L https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim.appimage > nvim.appimage) \
 && chmod a+x nvim.appimage \
 && ./nvim.appimage --appimage-extract \
 && rm nvim.appimage \
 && find ./squashfs-root -type d | xargs chmod a+rx \
 && true

#### Clone SpaceVim configuration ####
RUN true \
 && umask 0000 \
 && git clone --depth 1 https://github.com/SpaceVim/SpaceVim.git $HOME/.SpaceVim \
 && git clone --depth 1 https://github.com/thawk/dotspacevim.git $HOME/.SpaceVim.d \
 && rm -r $HOME/.SpaceVim/.git $HOME/.SpaceVim.d/.git \
 && mkdir -p $HOME/.config \
 && ln -s $HOME/.SpaceVim $HOME/.config/nvim \
 && sed -i \
    -e '/begin optional layers/,/end optional layers/ d' \
    -e '/^\([ \t]*\)\(checkinstall\)[ \t]*=.*$/s//\1\2 = 0/' \
    $HOME/.SpaceVim.d/init.toml \
 && git clone --depth 1 https://github.com/Shougo/dein.vim.git $HOME/.cache/vimfiles/repos/github.com/Shougo/dein.vim \
 && true

COPY run_nvim.sh ${HOME}
RUN true \
 && ln -s "${HOME}/squashfs-root/usr/bin/nvim" /usr/bin \
 && chmod a+x ${HOME}/run_nvim.sh \
 && true

# install fd-find
RUN true \
 && umask 0000 \
 && mkdir -p $HOME/fd \
 && (curl -L https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-x86_64-unknown-linux-musl.tar.gz | tar -C $HOME/fd --strip-components 1 -xz) \
 && mv $HOME/fd/autocomplete/fd.bash-completion /usr/share/bash-completion/completions/fd \
 && mv $HOME/fd/autocomplete/_fd /usr/share/zsh/site-functions/_fd \
 && mv $HOME/fd/fd.1 /usr/share/man/man1/ \
 && mv $HOME/fd/fd /usr/bin/ \
 && rm -rf $HOME/fd \
 && true

# install Facebook PathPicker
RUN true \
 && umask 0000 \
 && mkdir -p $HOME/fpp \
 && (curl -L https://github.com/facebook/PathPicker/archive/${FPP_VERSION}.tar.gz | tar -C $HOME/fpp --strip-components 1 -xz) \
 && ln -s $HOME/fpp/fpp /usr/bin \
 && true

COPY bashrc ${HOME}/.bashrc
COPY viminfo $HOME/.viminfo

ONBUILD COPY additional_pkg.txt $HOME/
ONBUILD RUN true \
 && cat $HOME/additional_pkg.txt | xargs --no-run-if-empty yum install -y \
 && yum clean all

ONBUILD COPY additional_pip.txt $HOME/
ONBUILD RUN true \
 && cat $HOME/additional_pip.txt | xargs --no-run-if-empty pip3 install \
 && true

ONBUILD COPY additional_vim.toml $HOME/
ONBUILD COPY SpaceVim.d $HOME/SpaceVim.d
ONBUILD RUN true \
 && umask 0000 \
 && cat $HOME/additional_vim.toml >> $HOME/.SpaceVim.d/init.toml \
 && cp -a $HOME/SpaceVim.d/* $HOME/.SpaceVim.d/ \
 && $HOME/run_nvim.sh --headless +'call dein#install()' +qall \
 && $HOME/run_nvim.sh --headless +UpdateRemotePlugins +qall \
 && find $HOME/.cache/vimfiles -type d -name ".git" | xargs --no-run-if-empty rm -r \
 && $HOME/run_nvim.sh --headless +qall \
 && mkdir -p $HOME/.local \
 && chmod 777 $HOME \
 && chmod 777 -R $HOME/{.config,.cache,.local} \
 && chmod a+rw -R $HOME/.npm \
 && chmod 666 $HOME/.viminfo \
 && true

# Clean Up
RUN rm -rf /tmp/* /var/tmp/*

ENV XDG_CACHE_HOME=/myhome/.cache
ENV XDG_CONFIG_HOME=/myhome/.config
ENV XDG_DATA_HOME=/myhome/.local/share
ENV EDITOR=/usr/bin/nvim
ENV SHELL=/usr/bin/bash
ENV PATH=$PATH:/myhome/bin
ENV PATH=$PATH:/myhome/localbin

WORKDIR /src
VOLUME /src

ENTRYPOINT ["/myhome/run_nvim.sh"]
