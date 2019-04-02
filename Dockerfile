FROM ubuntu:xenial
MAINTAINER "Chris Miller" <c.a.miller@wustl.edu>

RUN apt-get update -y && apt-get install -y \
    build-essential \
    cmake \
    curl \
    default-jdk \
    git \
    libncurses5-dev \
    libcurl4-openssl-dev \
    liblist-moreutils-perl \
    libtbb2 \
    libtbb-dev \
    nodejs \
    python-dev \
    python-pip \
    tzdata \
    wget \
    zlib1g-dev \
    zip

##############
#Picard 2.4.1#
##############
ENV picard_version 2.4.1

# Assumes Dockerfile lives in root of the git repo. Pull source files into
# container
RUN apt-get update && apt-get install ant --no-install-recommends -y && \
    cd /usr/ && \
    git config --global http.sslVerify false && \
    git clone --recursive https://github.com/broadinstitute/picard.git && \
    cd /usr/picard && \
    git checkout tags/${picard_version} && \
    cd /usr/picard && \
    # Clone out htsjdk. First turn off git ssl verification
    git config --global http.sslVerify false && \
    git clone https://github.com/samtools/htsjdk.git && \
    cd htsjdk && \
    git checkout tags/${picard_version} && \
    cd .. && \
    # Build the distribution jar, clean up everything else
    ant clean all && \
    mv dist/picard.jar picard.jar && \
    mv src/scripts/picard/docker_helper.sh docker_helper.sh && \
    ant clean && \
    rm -rf htsjdk && \
    rm -rf src && \
    rm -rf lib && \
    rm build.xml

##################
# ucsc utilities #
RUN mkdir -p /tmp/ucsc && \
    cd /tmp/ucsc && \
    wget http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/bedGraphToBigWig && \
    chmod ugo+x * && \
    mv * /usr/bin/ && \
    rm -rf /tmp/ucsc

###############
#Flexbar 3.0.3#
###############

RUN mkdir -p /opt/flexbar/tmp \
    && cd /opt/flexbar/tmp \
    && wget https://github.com/seqan/flexbar/archive/v3.0.3.tar.gz \
    && wget https://github.com/seqan/seqan/releases/download/seqan-v2.2.0/seqan-library-2.2.0.tar.xz \
    && tar xzf v3.0.3.tar.gz \
    && tar xJf seqan-library-2.2.0.tar.xz \
    && mv seqan-library-2.2.0/include flexbar-3.0.3 \
    && cd flexbar-3.0.3 \
    && cmake . \
    && make \
    && cp flexbar /opt/flexbar/ \
    && cd / \
    && rm -rf /opt/flexbar/tmp

######
# Needed for MGI mounts
######
RUN apt-get update -y && apt-get install -y libnss-sss

## clean up
RUN apt-get clean autoclean && apt-get autoremove -y
