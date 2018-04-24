FROM i386/debian:stretch-backports

################################################################################
### set metadata
ENV TOOL_NAME=msconvert
ENV TOOL_VERSION=3.0.18114
ENV CONTAINER_VERSION=1.1
ENV CONTAINER_GITHUB=https://github.com/phnmnl/container-pwiz

LABEL version="${CONTAINER_VERSION}"
LABEL software.version="${TOOL_VERSION}"
LABEL software="${TOOL_NAME}"
LABEL base.image="i386/debian:stretch-backports"
LABEL description="Convert LC/MS or GC/MS RAW vendor files to mzML."
LABEL website="${CONTAINER_GITHUB}"
LABEL documentation="${CONTAINER_GITHUB}"
LABEL license="${CONTAINER_GITHUB}"
LABEL tags="Metabolomics"

# we need wget, bzip2, wine from winehq, 
# xvfb to fake X11 for winetricks during installation,
# and winbind because wine complains about missing 
RUN apt-get update && \
    apt-get -y install wget gnupg && \
    echo "deb http://dl.winehq.org/wine-builds/debian/ stretch main" >> \
      /etc/apt/sources.list.d/winehq.list && \
    wget http://dl.winehq.org/wine-builds/Release.key -qO- | apt-key add - && \
    apt-get update && \
    apt-get -y --install-recommends install \
      bzip2 unzip curl \
      winehq-devel \
      winbind \
      xvfb \
      cabextract \
      && \
    apt-get -y clean && \
    rm -rf \
      /var/lib/apt/lists/* \
      /usr/share/doc \
      /usr/share/doc-base \
      /usr/share/man \
      /usr/share/locale \
      /usr/share/zoneinfo \
      && \
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
      -O /usr/local/bin/winetricks && chmod +x /usr/local/bin/winetricks

# put C:\pwiz on the Windows search path
ENV WINEARCH win32
ENV WINEDEBUG -all,err+all
ENV WINEPATH "C:\pwiz"
ENV DISPLAY :0
WORKDIR /root/

# wineserver needs to shut down properly!!! 
ADD waitonprocess.sh /root/waitonprocess.sh
RUN chmod +x waitonprocess.sh

# Install dependencies
RUN winetricks -q win7 && xvfb-run winetricks -q vcrun2008 corefonts && xvfb-run winetricks -q dotnet452 && ./waitonprocess.sh wineserver

#
# download ProteoWizard and extract it to C:\pwiz
#

# Pull latest version from TeamCity
# RUN wget -O- "https://teamcity.labkey.org/httpAuth/app/rest/builds/?locator=buildType:bt36,status:success,running:false,count:1&guest=1" | sed -e 's#.*build id=\"\([0-9]*\)\".*#\1#' >/tmp/pwiz.build

# To specify a particular build,
# e.g. https://teamcity.labkey.org/viewLog.html?buildId=574320&buildTypeId=bt36&tab=artifacts&guest=1
RUN echo "574320" >/tmp/pwiz.build

RUN wget -O /tmp/pwiz.version https://teamcity.labkey.org/repository/download/bt36/`cat /tmp/pwiz.build`:id/VERSION?guest=1

RUN mkdir /root/.wine/drive_c/pwiz && \
    wget https://teamcity.labkey.org/repository/download/bt36/`cat /tmp/pwiz.build`:id/pwiz-bin-windows-x86-vc120-release-`cat /tmp/pwiz.version | tr " " "_"`.tar.bz2?guest=1 -qO- | \
      tar --directory=/root/.wine/drive_c/pwiz -xj

## Prepare for container testing following 
## https://github.com/phnmnl/phenomenal-h2020/wiki/Testing-Guide-Proposal-3
ADD runTest1.sh /usr/local/bin/runTest1.sh
RUN chmod +x /usr/local/bin/runTest1.sh

ADD runTest2.sh /usr/local/bin/runTest2.sh
RUN chmod +x /usr/local/bin/runTest2.sh

# Set up working directory and permissions to let user xclient save data
RUN mkdir /data
WORKDIR /data

CMD ["wine", "msconvert" ]

## If you need a proxy during build, don't put it into the Dockerfile itself:
## docker build --build-arg http_proxy=http://www-cache.ipb-halle.de:3128/  -t phnmnl/pwiz:3.0.9098-0.1 .
