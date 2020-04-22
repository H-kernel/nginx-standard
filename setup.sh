#!/bin/bash
#set -x
set -o nounset
CURRENT_PATH=`pwd`
cd ${CURRENT_PATH}/..
export PREFIX_ROOT=/home/nginx/
export THIRD_ROOT=${CURRENT_PATH}/3rd_party/
export EXTEND_ROOT=${CURRENT_PATH}/extend/
export PATCH_ROOT=${CURRENT_PATH}/patch/
export SCRIPT_ROOT=${CURRENT_PATH}/script/

find=`env|grep PKG_CONFIG_PATH`    
if [ "find${find}" == "find" ]; then    
    export PKG_CONFIG_PATH=${EXTEND_ROOT}/lib/pkgconfig/
else
    export PKG_CONFIG_PATH=${EXTEND_ROOT}/lib/pkgconfig/:${PKG_CONFIG_PATH}
fi


find=`env|grep PATH`
if [ "find${find}" == "find" ]; then    
    export PATH=${EXTEND_ROOT}/bin/
else
    export PATH=${EXTEND_ROOT}/bin/:${PATH}
fi
echo "------------------------------------------------------------------------------"
echo " PKG_CONFIG_PATH: ${PKG_CONFIG_PATH}"
echo " PATH ${PATH}"
echo " CURRENT_PATH exported as ${CURRENT_PATH}"
echo "------------------------------------------------------------------------------"

host_type=`uname -p`

config_args=""

if [ "$host_type" = "aarch64" ];then
   config_args="--host=arm-linux --build=arm-linux"
fi

#WITHDEBUG="--with-debug"
export WITHDEBUG=""
#NGX_LINK="--add-dynamic-module"
NGX_LINK="--add-module"
#
# Sets QUIT variable so script will finish.
#
quit()
{
    QUIT=$1
}



build_pcre()
{
    module_pack="pcre-8.39.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the pcre package from server\n"
        wget https://sourceforge.net/projects/pcre/files/pcre/8.39/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd pcre*/
    ./configure ${config_args} --prefix=${EXTEND_ROOT} 
                
    if [ 0 -ne ${?} ]; then
        echo "configure pcre fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build pcre fail!\n"
        return 1
    fi
    
    return 0
}

build_zlib()
{
    module_pack="zlib-1.2.8.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the zlib package from server\n"
        wget http://zlib.net/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd zlib*/
    ./configure --prefix=${EXTEND_ROOT} 
                
    if [ 0 -ne ${?} ]; then
        echo "configure zlib fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build zlib fail!\n"
        return 1
    fi
    
    return 0
}

build_libiconv()
{
    module_pack="libiconv-1.16.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the libiconv package from server\n"
        wget http://ftp.gnu.org/pub/gnu/libiconv/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd libiconv*/
    patch -p0 <${PATCH_ROOT}/libiconv.patch
    ./configure ${config_args} --prefix=${EXTEND_ROOT} --enable-static=yes
                
    if [ 0 -ne ${?} ]; then
        echo "configure libiconv fail!\n"
        return 1
    fi
    
    make clean  
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build libiconv fail!\n"
        return 1
    fi
    
    return 0
}

build_bzip2()
{
    module_pack="bzip2-1.0.6.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the bzip2 package from server\n"
        wget http://www.bzip.org/1.0.6/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd bzip2*/
    #./configure ${config_args} --prefix=${EXTEND_ROOT}
    EXTEND_ROOT_SED=$(echo ${EXTEND_ROOT} |sed -e 's/\//\\\//g')
    sed -i "s/PREFIX\=\/usr\/local/PREFIX\=${EXTEND_ROOT_SED}/" Makefile    
    sed -i "s/CFLAGS=-Wall -Winline -O2 -g/CFLAGS\=-Wall -Winline -O2 -fPIC -g/" Makefile
    if [ 0 -ne ${?} ]; then
        echo "sed bzip2 fail!\n"
        return 1
    fi
                
    make && make install
    
    if [ 0 -ne ${?} ]; then
        echo "build bzip2 fail!\n"
        return 1
    fi
    
    return 0
}


build_openssl()
{
    module_pack="OpenSSL_1_0_2s.tar.gz"
    cd ${THIRD_ROOT}
    if [ ! -f ${THIRD_ROOT}${module_pack} ]; then
        echo "start get the openssl package from server\n"
        wget https://www.openssl.org/source/old/0.9.x/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd openssl*/
                    
    if [ 0 -ne ${?} ]; then
        echo "get openssl fail!\n"
        return 1
    fi

    ./config shared --prefix=${EXTEND_ROOT}
    if [ 0 -ne ${?} ]; then
        echo "config openssl fail!\n"
        return 1
    fi
    
    make clean
    
    make
    if [ 0 -ne ${?} ]; then
        echo "make openssl fail!\n"
        return 1
    fi
    make test
    if [ 0 -ne ${?} ]; then
        echo "make test openssl fail!\n"
        return 1
    fi
    make install_sw
    if [ 0 -ne ${?} ]; then
        echo "make install openssl fail!\n"
        return 1
    fi
    
    return 0
}

build_extend_modules()
{
    build_bzip2
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_zlib
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_pcre
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_libiconv
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    build_openssl
    if [ 0 -ne ${?} ]; then
        return 1
    fi
    return 0
}

build_nginx_module()
{
    cd ${CURRENT_PATH}
    ###wget the allmedia
    module_pack="nginx-1.18.0.tar.gz"
    if [ ! -f ${CURRENT_PATH}/${module_pack} ]; then
        echo "start get the nginx package from server\n"
        wget http://nginx.org/download/${module_pack}
    fi
    tar -zxvf ${module_pack}
    
    cd nginx*/
    
    basic_opt=" --prefix=${PREFIX_ROOT} 
                --with-threads 
                --with-file-aio 
                --with-http_ssl_module 
                --with-http_realip_module 
                --with-http_addition_module 
                --with-http_sub_module 
                --with-http_dav_module 
                --with-http_flv_module 
                --with-http_mp4_module 
                --with-http_gunzip_module 
                --with-http_gzip_static_module 
                --with-http_random_index_module 
                --with-http_secure_link_module 
                --with-http_stub_status_module 
                --with-http_auth_request_module 
                --with-mail 
                --with-mail_ssl_module 
                --with-cc-opt=-O3 "
                
    
    third_opt=""
    cd ${THIRD_ROOT}/pcre*/
    if [ 0 -eq ${?} ]; then
        third_opt="${third_opt} 
                    --with-pcre=`pwd`"
    fi
    cd ${THIRD_ROOT}/zlib*/
    if [ 0 -eq ${?} ]; then
        third_opt="${third_opt}
                    --with-zlib=`pwd`"
    fi
    cd ${THIRD_ROOT}/openssl*/
    if [ 0 -eq ${?} ]; then
        third_opt="${third_opt} 
                    --with-openssl=`pwd`"
    fi
        
    all_opt="${basic_opt} ${third_opt}"
    
    echo "all optiont info:\n ${all_opt}"
    
    cd ${CURRENT_PATH}/nginx/
    chmod +x configure
    ./configure ${all_opt} 

    if [ 0 -ne ${?} ]; then
       echo "configure the nginx fail!\n"
       return 1
    fi
    
    make&&make install
    
    if [ 0 -ne ${?} ]; then
       echo "make the nginx fail!\n"
       return 1
    fi   

    echo "make the nginx success!\n"
    cd ${CURRENT_PATH}
    return 0
}


build_nginx()
{
        
    build_extend_modules
    if [ 0 -ne ${?} ]; then
        return
    fi 
    build_nginx_module
    if [ 0 -ne ${?} ]; then
        return
    fi
    echo "make the all modules success!\n"
    cd ${CURRENT_PATH}
}


all_func()
{
        TITLE="build module  "
        
        TEXT[1]="build all module"
        FUNC[1]="build_nginx"
        
        TEXT[2]="build nginx module"
        FUNC[2]="build_nginx_module"
}
STEPS[1]="all_func"

QUIT=0

while [ "$QUIT" == "0" ]; do
    OPTION_NUM=1
    if [ ! -x "`which wget 2>/dev/null`" ]; then
        echo "Need to install wget."
        break 
    fi
    for s in $(seq ${#STEPS[@]}) ; do
        ${STEPS[s]}

        echo "----------------------------------------------------------"
        echo " Step $s: ${TITLE}"
        echo "----------------------------------------------------------"

        for i in $(seq ${#TEXT[@]}) ; do
            echo "[$OPTION_NUM] ${TEXT[i]}"
            OPTIONS[$OPTION_NUM]=${FUNC[i]}
            let "OPTION_NUM+=1"
        done

        # Clear TEXT and FUNC arrays before next step
        unset TEXT
        unset FUNC

        echo ""
    done

    echo "[$OPTION_NUM] Exit Script"
    OPTIONS[$OPTION_NUM]="quit"
    echo ""
    echo -n "Option: "
    read our_entry
    echo ""
    ${OPTIONS[our_entry]} ${our_entry}
    echo
done
