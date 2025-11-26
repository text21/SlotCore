local MetricsExporter = {}

function MetricsExporter.new(opts)
    local self = {}
    self._counters = {}
    self._gauges = {}
    self._flushFn = opts and opts.flushFn
    return self
end

function MetricsExporter:inc(name, amount)
    amount = amount or 1
    self._counters[name] = (self._counters[name] or 0) + amount
    if self._flushFn then pcall(self._flushFn, name, self._counters[name]) end
end

function MetricsExporter:gauge(name, value)
    self._gauges[name] = value
    if self._flushFn then pcall(self._flushFn, name, value) end
end

function MetricsExporter:getCounters()
    return self._counters
end

function MetricsExporter:getGauges()
    return self._gauges
end

return MetricsExporter
