# 网络请求缓存系统实现任务计划

## 任务概览

实现一套两级缓存系统（内存+磁盘），支持 6 种缓存策略，通过 `FLXApiCachePolicy` 配置，可独立为每个 API 设置缓存行为。

---

## 任务清单

- [x] Task 1: 创建 FLXApiCacheType 缓存类型枚举
    - 1.1: 在 `api_enums.dart` 中添加 `FLXApiCacheType` 枚举
    - 1.2: 定义 6 种缓存类型：noCache, cacheFirst, cacheThenNetwork, networkThenCache, networkOnlyCache, cacheOnly

- [x] Task 2: 创建 FLXApiCacheLevel 缓存级别枚举
    - 2.1: 在 `api_enums.dart` 中添加 `FLXApiCacheLevel` 枚举
    - 2.2: 定义 3 种级别：memoryOnly, diskOnly, memoryAndDisk

- [x] Task 3: 创建 FLXApiCacheEntry 缓存条目类
    - 3.1: 创建 `FLXApiCacheEntry<T>` 泛型类
    - 3.2: 实现缓存数据、时间、过期时间、响应头等字段
    - 3.3: 实现 isExpired 和 isNearExpired 判断逻辑

- [x] Task 4: 创建 FLXApiCachePolicy 缓存策略配置类
    - 4.1: 创建 `FLXApiCachePolicy` 配置类
    - 4.2: 实现 type、memoryDuration、diskDuration、maxMemoryCount、maxMemorySize、level 等配置字段
    - 4.3: 实现 defaultCache() 和 memoryOnly() 工厂方法

- [x] Task 5: 创建 FLXApiCache 缓存管理器（核心实现）
    - 5.1: 创建 `FLXApiCache` 单例类
    - 5.2: 实现内存缓存（LRU LinkedHashMap）
    - 5.3: 实现磁盘缓存（shared_preferences）
    - 5.4: 实现 get() 方法：内存优先，支持磁盘回填
    - 5.5: 实现 set() 方法：两级缓存同步写入
    - 5.6: 实现 remove()、clear()、clearExpired() 方法
    - 5.7: 实现 generateKey() 方法（MD5 哈希）
    - 5.8: 实现 LRU 淘汰逻辑（容量超限时淘汰最久未使用）
    - 5.9: 实现缓存统计（memoryHitCount、diskHitCount）

- [x] Task 6: 扩展 FLXApiOptions
    - 6.1: 在 `api_options.dart` 中添加 `cachePolicy` 字段
    - 6.2: 在构造函数中添加 `cachePolicy` 参数

- [x] Task 7: 扩展 FLXCommonApi 集成缓存逻辑
    - 7.1: 在 `api.dart` 中添加 `_queryWithCache()` 方法
    - 7.2: 实现 `_cacheFirstStrategy()` 缓存优先策略
    - 7.3: 实现 `_cacheThenNetworkStrategy()` 缓存优先并异步更新策略
    - 7.4: 实现 `_networkThenCacheStrategy()` 网络优先降级策略
    - 7.5: 实现 `_networkOnlyCacheStrategy()` 仅网络缓存策略
    - 7.6: 实现 `_cacheOnlyStrategy()` 仅缓存策略
    - 7.7: 修改 `query()` 方法支持缓存分发
    - 7.8: 实现请求去重（使用 Completer）

- [x] Task 8: 导出新增类型
    - 8.1: 在 `flux_core.dart` 中导出 FLXApiCache 缓存模块

---

## 实现顺序

1. **枚举定义** (Task 1-2)：定义缓存类型和级别枚举
2. **数据结构** (Task 3-4)：缓存条目和策略配置
3. **缓存核心** (Task 5)：缓存管理器实现
4. **集成** (Task 6-7)：与现有 API 系统集成
5. **导出** (Task 8)：模块导出

---

## 任务完成状态

✅ 所有任务已完成，代码已通过 `flutter analyze` 检查