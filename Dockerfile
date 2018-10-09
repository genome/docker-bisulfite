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
    libtbb2 \
    libtbb-dev \
    nodejs \
    python-dev \
    python-pip \
    tzdata \
    wget \
    zlib1g-dev \
    zip

##################
# Biscuit v0.3.8 #
##################
# RUN cd /tmp/ && \
#     wget https://github.com/zwdzwd/biscuit/archive/v0.3.8.20180515.zip && \
#     unzip v0.3.8.20180515.zip && \
    # cd biscuit-0.3.8.20180515 && \
    # make && \
    # cp biscuit /usr/bin && \
    # rm -rf /tmp/biscuit*
RUN mkdir /opt/biscuit && cd /opt/biscuit && wget https://github.com/zwdzwd/biscuit/releases/download/v0.3.8.20180515/biscuit_0_3_8_x86_64 && \
    chmod +x biscuit_0_3_8_x86_64 && cd /usr/bin && ln -s /opt/biscuit/biscuit_0_3_8_x86_64

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

#################
#Sambamba v0.6.4#
#################

RUN mkdir /opt/sambamba/ \
    && wget https://github.com/lomereiter/sambamba/releases/download/v0.6.4/sambamba_v0.6.4_linux.tar.bz2 \
    && tar --extract --bzip2 --directory=/opt/sambamba --file=sambamba_v0.6.4_linux.tar.bz2 \
    && ln -s /opt/sambamba/sambamba_v0.6.4 /usr/bin/sambamba
   ADD sambamba_merge /usr/bin/
   RUN chmod +x /usr/bin/sambamba_merge

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

##############
#HTSlib 1.3.2#
##############
ENV HTSLIB_INSTALL_DIR=/opt/htslib

WORKDIR /tmp
RUN wget https://github.com/samtools/htslib/releases/download/1.3.2/htslib-1.3.2.tar.bz2 && \
    tar --bzip2 -xvf htslib-1.3.2.tar.bz2 && \
    cd /tmp/htslib-1.3.2 && \
    ./configure  --enable-plugins --prefix=$HTSLIB_INSTALL_DIR && \
    make && \
    make install && \
    cp $HTSLIB_INSTALL_DIR/lib/libhts.so* /usr/lib/

################
#Samtools 1.3.1#
################
ENV SAMTOOLS_INSTALL_DIR=/opt/samtools

WORKDIR /tmp
RUN wget https://github.com/samtools/samtools/releases/download/1.3.1/samtools-1.3.1.tar.bz2 && \
    tar --bzip2 -xf samtools-1.3.1.tar.bz2 && \
    cd /tmp/samtools-1.3.1 && \
    ./configure --with-htslib=$HTSLIB_INSTALL_DIR --prefix=$SAMTOOLS_INSTALL_DIR && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/samtools-1.3.1
    
#wrapper script for converting vcf2bed
ADD bsvcf2bed /usr/bin/

######
#Toil#
######
RUN apt-get update -y && apt-get install -y \
    nodejs \
    python-dev \
    python-pip \
    tzdata 
#RUN pip install --upgrade pip \
#    && pip install toil[cwl]==3.12.0 \
#    && sed -i 's/select\[type==X86_64 && mem/select[mem/' /usr/local/lib/python2.7/dist-packages/toil/batchSystems/lsf.py
RUN pip install toil[cwl]==3.12.0  && sed -i 's/select\[type==X86_64 && mem/select[mem/' /usr/local/lib/python2.7/dist-packages/toil/batchSystems/lsf.py

######
# Needed for MGI mounts
######
RUN apt-get update -y && apt-get install -y libnss-sss

## clean up
RUN apt-get clean autoclean && apt-get autoremove -y
