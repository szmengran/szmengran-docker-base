#!/bin/bash
set -e
set -x

function parseArgs() {
  suspend='n'

  for i in "$@"; do
    case $i in
    --app=*)
      APP="${i#*=}"
      shift # past argument=value
      ;;
    --main=*)
      MAIN_CLASS="${i#*=}"
      shift # past argument=value
      ;;
    --profile=*)
      ACTIVE_PROFILE="${i#*=}"
      export ACTIVE_PROFILE
      shift # past argument=value
      ;;
    --namespace=*)
      POD_NAMESPACE="${i#*=}"
      shift # past argument=value
      ;;
    --ip=*)
      POD_IP="${i#*=}"
      shift # past argument=value
      ;;
    --branch=*)
      BRANCH="${i#*=}"
      export BRANCH
      shift # past argument=value
      ;;
    --unit=*)
      unit="${i#*=}"
      shift # past argument=value
      ;;
    --debug)
      ENABLE_JVM_DEBUG="true"
      shift # past argument with no value
      ;;
    --suspend=*)
      wait="${i#*=}"
      if [[ "$wait" == 'true' ]]; then
        suspend='y'
      fi
      shift
      ;;
    --beta)
      beta="true"
      shift # past argument with no value
      ;;
    --skywalking)
      enable_skywalking="true"
      shift # past argument with no value
      ;;
    --spare=true)
      spare="true"
      shift # past argument with no value
      ;;
    *)
      # unknown option
      ;;
    esac
  done
}

function prepare() {
  if [[ "$APP" == "" ]] || [[ "$MAIN_CLASS" == "" ]]; then
    echo "missing arg : APP or MAIN_CLASS"
    exit 1
  fi

  if [[ "$POD_NAMESPACE" == "" ]] || [[ "$POD_IP" == "" ]]; then
    echo "missing ENV : POD_NAMESPACE or POD_IP"
    exit 1
  fi

  work_dir=$(pwd)
  cp -r /app $work_dir/$APP

  export pp_version="1.8.5"

  # mount to override

  if [[ -d .skywalking-config ]] && [ "$(ls .skywalking-config)" ] ; then
    cp .skywalking-config/* skywalking-agent/config/
  fi

  if [[ -f shell/$APP-config.sh ]]; then
    source shell/$APP-config.sh
  fi

  if [[ -f shell/${ACTIVE_PROFILE}-config.sh ]]; then
    source shell/${ACTIVE_PROFILE}-config.sh
  fi

  if [[ -f shell/${APP}-${ACTIVE_PROFILE}-config.sh ]]; then
    source shell/$APP-$ACTIVE_PROFILE-config.sh
  fi

  app_dir=$work_dir/$APP
  log_dir=$work_dir/logs/$POD_NAMESPACE/$APP

#  if ! mkdir -p $log_dir
#  then
#    log_dir=/data/logs/$POD_NAMESPACE/$APP
#    mkdir -p $log_dir
#  fi

  if [[ ! -d $log_dir ]]; then
    mkdir -p $log_dir
  fi
  ln -s -T $log_dir $app_dir/log
#  ln -s -T $log_dir/userLog $app_dir/userLog

  # for crm
#  ln -s -T $work_dir/logs/$POD_NAMESPACE /data/logs
}

function jvmBaseOpts() {

  # memory limit in bytes
  mem_limit=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)

  # memory limit in mega bytes
  mem_limit_in_mb=$(awk 'BEGIN{printf "%d",('${mem_limit}'/1048576)}')

  if [[ ${mem_limit_in_mb} -lt 800 ]]; then
    echo "docker memory limit must NOT less than 800m"
  fi

  meta_size=256

  if [[ ${mem_limit_in_mb} -le 2048 ]]; then
    heap_size=$(awk 'BEGIN{printf "%d",('${mem_limit_in_mb}'*0.6)}')
  elif [[ ${mem_limit_in_mb} -le 4096 ]]; then
    heap_size=$(awk 'BEGIN{printf "%d",('${mem_limit_in_mb}'*0.65)}')
  elif [[ ${mem_limit_in_mb} -le 8192 ]]; then
    heap_size=$(awk 'BEGIN{printf "%d",('${mem_limit_in_mb}'*0.7)}')
  else
    heap_size=$(awk 'BEGIN{printf "%d",('${mem_limit_in_mb}'*0.8)}')
  fi

  if [[ ${heap_size} -ge 3072 ]]; then
    meta_size=512
  fi

  #if [[ ${heap_size} -gt 8192 ]]; then
  #  heap_size=8192
  #fi

  new_size=$(awk 'BEGIN{printf "%d",('${heap_size}'*0.5)}')

  #垃圾收集器
  #-XX:+UseSerialGC，设置串行收集器
  #-XX:+UseParallelGC，设置并行收集器
  #-XX:+UseConcMarkSweepGC，使用CMS收集器
  #-XX:ParallelGCThreads，设置Parallel GC的线程数
  #-XX:+UseG1GC，使用G1垃圾收集器

  #-Xmn新生代内存的大小，包括Eden区和两个Survivor区的总和，写法如：-Xmn1024，-Xmn1024k，-Xmn1024m，-Xmn1g 。
  #-Xms堆内存的最小值，默认值是总内存/64（且小于1G）。默认情况下，当堆中可用内存小于40%（这个值可以用-XX: MinHeapFreeRatio 调整，如-X:MinHeapFreeRatio=30）时，堆内存会开始增加，直增加到-Xmx的大小。
  #-Xmx堆内存的最大值，默认值是总内存/4（且小于1G）。默认情况下，当堆中可用内存大于70%（这个值可以用-XX: MaxHeapFreeRatio调整，如-X:MaxHeapFreeRatio =80）时，堆内存会开始减少，一直减小到-Xms的大小。 *如果Xms和Xmx都不设置，则两者大小会相同*
  #-Xss每个线程的栈内存，默认1M，般来说是不需要改的。
  #-Xrs减少JVM对操作系统信号的使用。
  #-Xprof跟踪正运行的程序，并将跟踪数据在标准输出输出。适合于开发环境调试。
  #-Xnoclassgc关闭针对class的gc功能。因为其阻至内存回收，所以可能会导致OutOfMemoryError错误，慎用。
  #-Xincgc开启增量gc（默认为关闭）。这有助于减少长时间GC时应用程序出现的停顿，但由于可能和应用程序并发执行，所以会降低CPU对应用的处理能力。
  #-Xloggc:file与-verbose:gc功能类似，只是将每次GC事件的相关情况记录到一个文件中，文件的位置最好在本地，以避免网络的潜在问题。

  #-Xms4g：初始化堆内存大小为4GB，ms是memory start的简称，等价于-XX:InitialHeapSize。
  #-Xmx4g：堆内存最大值为4GB，mx是memory max的简称，等价于-XX:MaxHeapSize。
  #-Xmn1200m：设置年轻代大小为1200MB。增大年轻代后，将会减小老年代大小。此值对系统性能影响较大，Sun官方推荐配置为整个堆的3/8。
  #-Xss512k：设置每个线程的堆栈大小。JDK5.0以后每个线程堆栈大小为1MB，以前每个线程堆栈大小为256K。应根据应用线程所需内存大小进行调整。在相同物理内存下，减小这个值能生成更多的线程。但是操作系统对一个进程内的线程数还是有限制的，不能无限生成，经验值在3000~5000左右。
  #-XX:NewRatio=4：设置年轻代（包括Eden和两个Survivor区）与老年代的比值（除去持久代）。设置为4，则年轻代与老年代所占比值为1：4，年轻代占整个堆栈的1/5
  #-XX:SurvivorRatio=8：设置年轻代中Eden区与Survivor区的大小比值。设置为8，则两个Survivor区与个Eden区的比值为2:8，个Survivor区占整个年轻代的1/10
  #-XX:PermSize=100m：初始化永久代大小为100MB。
  #-XX:MaxPermSize=256m：设置持久代大小为256MB。
  #-XX:MaxTenuringThreshold=15：设置垃圾最大年龄。如果设置为0的话，则年轻代对象不经过Survivor区，直接进入老年代。对于老年代比较多的应用，可以提高效率。如果将此值设置为个较大值，则年轻代对象会在Survivor区进行多次复制，这样可以增加对象在年轻代的存活时间，增加在年轻代即被回收的概率。
  #-XX:MaxDirectMemorySize=1G：直接内存。报java.lang.OutOfMemoryError: Direct buffermemory异常可以上调这个值。
  #-XX:+DisableExplicitGC：禁止运行期显式地调用System.gc()来触发fulll GC。 注意: Java RMI的定时GC触发机制可通过配置-Dsun.rmi.dgc.server.gcInterval=86400来控制触发的时间。
  #-XX:CMSInitiatingOccupancyFraction=60：老年代内存回收阈值，默认值为68。
  #-XX:ConcGCThreads=4：CMS垃圾回收器并行线程线，推荐值为CPU核心数。
  #-XX:ParallelGCThreads=8：新生代并行收集器的线程数。
  #-XX:CMSMaxAbortablePrecleanTime=500：当abortable-preclean预清理阶段执行达到这个时间时就会结束。
  #-XX:+UnlockExperimentalVMOptions：用于解锁实验性参数，如果不加该标记，不会打印实验性参数
  #-XX:+UnlockDiagnosticVMOptions：用于解锁诊断性参数，如果不加该标记，不会打印诊断性参数
  #-XX:+ParallelRefProcEnabled：可以用来并行处理 Reference，以加快处理速度，缩短耗时
  #-XX:G1HeapRegionSize：用于设置小堆区大小，建议保持默认
  #-XX:MaxRAMPercentage：最大的堆内存百分比，简单来说，机器（容器）内存*MaxRAMPercentage/100=最大堆内存
  #-XX:InitialRAMPercentage：初始化堆内存百分比，简单来说，机器（容器）内存*InitialRAMPercentage/100=初始化堆内存大小
  #-XX:MaxDirectMemorySize=size用于设置New I/O(java.nio) direct-buffer allocations的最大大小，size的单位可以使用k/K、m/M、g/G；如果没有设置该参数则默认值为0，意味着JVM自己自动给NIO direct-buffer allocations选择最大大小
  #-XX:+AlwaysPreTouch：在没有配置-XX:+AlwaysPreTouch参数即默认情况下，JVM参数-Xms申明的堆只是在虚拟内存中分配，而不是在物理内存中分配，G1修复了这类问题，所以忽略AlwaysPreTouch
  #-XX:InitialCodeCacheSize和-XX:ReservedCodeCacheSize：这个参数主要设置codecache的大小，比如我们jit编译的代码都是放在codecache里的，所以codecache如果满了的话，那带来的问题就是无法再jit编译了，而且还会去优化。因此大家可能碰到这样的问题：cpu一直高，然后发现是编译线程一直高（系统运行到一定时期），这个很大可能是codecache满了，一直去做优化。
  #-XX:-UseBiasedLocking：在JDK1.6以后默认已经开启了偏向锁这个优化，我们可以通过在启动JVM的时候加上-XX:-UseBiasedLocking参数来禁用偏向锁
  #-XX:+UseCountedLoopSafepoints：可以避免GC发生时，线程因长时间运行counted loop，进入不到safepoint，而引起GC的STW时间过长
  #-XX:+SafepointTimeout -XX:SafepointTimeoutDelay=1000：通过添加JVM参数-XX:+SafepointTimeout -XX:SafepointTimeoutDelay=1000后，可打印出哪些线程超过1000ms没有到达safepoint
  #-XX:StartFlightRecording：有了这个参数就会启用 JFR 记录

  #-XX:-OmitStackTraceInFastThrow：这是HotSpot VM专门针对异常做的一个优化,默认启用,当一些异常在代码里某个特定位置被抛出很多次的话,HotSpot Server Compiler（C2）会用fast throw来优化这个抛出异常的地方,直接抛出一个事先分配好的,类型匹配的对象,这个对象的message和stack trace都被清空.

  jvm_mem_opts="-Xms300m -XX:MinHeapFreeRatio=40 -Xmx${heap_size}m -XX:MaxHeapFreeRatio=70 -Xss512k \
              -XX:MetaspaceSize=${meta_size}m -XX:MaxMetaspaceSize=${meta_size}m \
              -XX:MaxTenuringThreshold=15 \
              -XX:+SafepointTimeout -XX:SafepointTimeoutDelay=1000 -XX:+UseCountedLoopSafepoints \
              -XX:+UnlockExperimentalVMOptions -XX:+UnlockDiagnosticVMOptions"

  # less than 8G use CMS, G1 otherwise MAX: 8G
  if [[ ${heap_size} -lt 4096 ]]; then
    jvm_mem_opts="$jvm_mem_opts -XX:+UseZGC \
                                    --add-opens java.base/java.lang=ALL-UNNAMED \
                                    --add-opens java.base/java.io=ALL-UNNAMED --add-opens java.base/java.math=ALL-UNNAMED \
                                    --add-opens java.base/java.net=ALL-UNNAMED --add-opens java.base/java.nio=ALL-UNNAMED \
                                    --add-opens java.base/java.security=ALL-UNNAMED --add-opens java.base/java.text=ALL-UNNAMED \
                                    --add-opens java.base/java.time=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED \
                                    --add-opens java.base/jdk.internal.access=ALL-UNNAMED --add-opens java.base/jdk.internal.misc=ALL-UNNAMED"
  else
    jvm_mem_opts="$jvm_mem_opts -XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:+ParallelRefProcEnabled"
  fi

  if [[ "$ENABLE_JVM_DEBUG" == "true" ]]; then
    jvm_debug="-agentlib:jdwp=transport=dt_socket,server=y,suspend=${suspend},address=5005"
  fi

  opts="$jvm_mem_opts $jvm_debug -XX:-OmitStackTraceInFastThrow -Xloggc:$log_dir/jvm.log \
      -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=${log_dir} -XX:ErrorFile=${log_dir}/hs_err_pid%p.log"
}

function appOpts() {
  ts=$(date +%s%3N)
  # common opts
  opts="$opts -Dserver.port=8080 \
      -Dmanagement.server.port=8088 \
      -Dmanagement.server.address=127.0.0.1 \
      -Dmanagement.endpoints.web.exposure.include=* \
      -Djava.security.egd=file:/dev/./urandom \
      -Dhttp.maxConnections=200 \
      -Dfile.encoding=UTF-8"

  opts="$opts -Ddubbo.protocol.port=9090 \
      -Ddubbo.application.logger=slf4j \
      -Ddubbo.application.qos.enable=true \
      -Ddubbo.application.qos.port=9099 \
      -Ddubbo.application.qos.accept.foreign.ip=false"

  # log4j漏洞，临时修补，log4j版本升级后可去掉
  opts="$opts -Dlog4j2.formatMsgNoLookups=true"

  # profile release opts
  if [[ "$ACTIVE_PROFILE" == *test ]]; then
    opts="$opts -XX:MaxJavaStackTraceDepth=10240"
    set +e
    framework=$(grep framework.version /app/classes/git.properties 2>/dev/null)
    set -e
#    if [[ ! -z "$framework" ]]; then
#      opts="$opts -Ddubbo.consumer.cluster=zoneAware"
#    fi
    opts="$opts -Ddubbo.zone=$BRANCH \
    -Dgit.branch=$BRANCH \
    -szmengran.fallbackZone=master \
    -Drocketmq.affinity.enable=true -Drocketmq.affinity.zone=$BRANCH \
    -Dza.core-user.test.enable=true"
  fi

  if [[ ! -z "$unit" ]]; then
    nacos_ns="$unit"
    if [[ "$ACTIVE_PROFILE" == *test ]]; then
      nacos_ns="$unit-test"
    fi
    opts="$opts -Dspring.cloud.nacos.username=${unit} -Dspring.cloud.nacos.password=${unit} \
            -Dspring.cloud.nacos.config.namespace=${nacos_ns}"
    upcase_unit=$(echo $unit | tr '[a-z]' '[A-Z]')
    opts="$opts -Dapp=${APP}-${unit} -Dproject.name=${APP}-${unit} -Dprovider.appId=${upcase_unit}"
  else
    opts="$opts -Dapp=${APP}"
  fi

  # app_related_opts应该在$APP-$ACTIVE_PROFILE-config.sh中定义
  opts="$opts $app_related_opts"

  # elif [[ "$ACTIVE_PROFILE" == "test" ]]; then
  #    export SW_AGENT_NAME="$APP"
  #    opts="$opts -javaagent:${work_dir}/skywalking-agent/skywalking-agent.jar"
  fi

  # skywalking
  if [[ "$enable_skywalking" == "true" ]] ; then
    opts="$opts -javaagent:${work_dir}/skywalking-agent/skywalking-agent.jar${SW_AGENT_OPTIONS}"
  fi


  for jarfile in $app_dir/libs-szmengran/*.jar; do
    if [[ "$jarfile" == $app_dir/libs-szmengran/szmengran-framework-starter-instrument-* ]]; then
      opts="$opts -javaagent:$jarfile"
      break
    fi
  done

  post_opts="--spring.profiles.active=$ACTIVE_PROFILE"

  if [[ ! -z "${unit}" ]]; then
    post_opts="$post_opts --spring.cloud.config.name=${APP}-${unit}"
  fi
  if [[ "$beta" == "true" ]]; then
    post_opts="$post_opts --spring.application.name=${APP}-beta"
  fi
}

function run() {
  # start
  java_exe=/usr/bin/java
  run_cmd="$java_exe -cp $app_dir/classes:$app_dir/libs-szmengran/*:$app_dir/libs/* $opts $MAIN_CLASS $post_opts"

  cat >start.sh <<EOF
#!/bin/bash
${run_cmd}
EOF

  chmod +x start.sh
  nohup ${run_cmd} >/dev/stdout 2>&1 &

  if [[ -f $APP/bin/post-start.sh ]]; then
    sh $APP/bin/post-start.sh &
  fi

  tail -f /dev/null
}

function main() {
  parseArgs "$@"
  prepare
  jvmBaseOpts
  appOpts
  run
}

main "$@"
