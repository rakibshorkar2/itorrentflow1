#import <Foundation/Foundation.h>

// MARK: - C-compatible bridge interface for LibTorrent

typedef struct lt_session_handle *LTSessionRef;

/// Callback for torrent status updates
typedef void (^LTStatusCallback)(const char *infoHash, double progress,
                                 int64_t downloadRate, int64_t uploadRate,
                                 int connectedPeers, int totalPeers,
                                 int state, const char *stateStr);

/// Callback for piece completion
typedef void (^LTPieceCallback)(const char *infoHash, int pieceIndex);

/// Callback for log messages
typedef void (^LTLogCallback)(const char *message);

// MARK: - Lifecycle
LTSessionRef lt_session_create(void);
void lt_session_destroy(LTSessionRef session);

// MARK: - Configuration
void lt_session_set_listen_port(LTSessionRef session, int port);
void lt_session_set_max_connections(LTSessionRef session, int max);
void lt_session_set_max_upload_rate(LTSessionRef session, int64_t bytesPerSec);
void lt_session_set_max_download_rate(LTSessionRef session, int64_t bytesPerSec);
void lt_session_enable_dht(LTSessionRef session, bool enable);
void lt_session_enable_lsd(LTSessionRef session, bool enable);
void lt_session_enable_upnp(LTSessionRef session, bool enable);
void lt_session_enable_natpmp(LTSessionRef session, bool enable);

// MARK: - Adding Torrents
const char *lt_session_add_torrent(LTSessionRef session, const char *torrentData,
                                   int dataLength, const char *savePath,
                                   const char **trackers, int trackerCount);
const char *lt_session_add_magnet(LTSessionRef session, const char *magnetURI,
                                  const char *savePath);

// MARK: - Control
void lt_session_pause(LTSessionRef session, const char *infoHash);
void lt_session_resume(LTSessionRef session, const char *infoHash);
void lt_session_remove(LTSessionRef session, const char *infoHash, bool deleteFiles);

// MARK: - File Priority
void lt_session_set_file_priority(LTSessionRef session, const char *infoHash,
                                  int fileIndex, int priority);

// MARK: - Status
void lt_session_set_callbacks(LTSessionRef session,
                              LTStatusCallback statusCb,
                              LTPieceCallback pieceCb,
                              LTLogCallback logCb);

// MARK: - Tracker Management
void lt_session_add_tracker(LTSessionRef session, const char *infoHash,
                            const char *trackerURL);
void lt_session_replace_trackers(LTSessionRef session, const char *infoHash,
                                 const char **trackers, int count);

// MARK: - DHT
void lt_session_add_dht_node(LTSessionRef session, const char *host, int port);
void lt_session_add_dht_router(LTSessionRef session, const char *host, int port);

// MARK: - Pause / Resume All
void lt_session_pause_all(LTSessionRef session);
void lt_session_resume_all(LTSessionRef session);
