#pragma once
#include <QtGlobal>

namespace mxvpn {
struct TrafficSnapshot {
    quint64 receivedBytes = 0;
    quint64 sentBytes = 0;
    double downloadPerSecond = 0;
    double uploadPerSecond = 0;
    void sample(quint64 received, quint64 sent, qint64 nowMilliseconds) {
        downloadPerSecond = uploadPerSecond = 0;
        const auto interval = nowMilliseconds - previousTime;
        if (hasPrevious && interval > 0 && received >= receivedBytes && sent >= sentBytes) {
            downloadPerSecond = double(received - receivedBytes) * 1000.0 / double(interval);
            uploadPerSecond = double(sent - sentBytes) * 1000.0 / double(interval);
        }
        receivedBytes = received;
        sentBytes = sent;
        previousTime = nowMilliseconds;
        hasPrevious = true;
    }
private:
    bool hasPrevious = false;
    qint64 previousTime = 0;
};
}
