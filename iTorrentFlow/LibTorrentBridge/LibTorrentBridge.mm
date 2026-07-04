#import "LibTorrentBridge.h"

#if __has_include(<libtorrent/session.hpp>)

// LibTorrent C++ headers
#include <libtorrent/session.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/torrent_handle.hpp>
#include <libtorrent/alert_types.hpp>
#include <libtorrent/magnet_uri.hpp>

#include <map>
#include <string>
#include <vector>

using namespace lt;

struct lt_session {
    session ses;
    std::map<std::string, torrent_handle> handles;
    LTStatusCallback statusCb;
    LTPieceCallback pieceCb;
    LTLogCallback logCb;
};

static lt_session *get_session(LTSessionRef ref) {
    return static_cast<lt_session *>(ref);
}

LTSessionRef lt_session_create(void) {
    auto *s = new lt_session();
    settings_pack pack;
    pack.set_int(settings_pack::alert_mask, alert::status_notification |
                 alert::error_notification | alert::progress_notification |
                 alert::storage_notification | alert::peer_notification);
    pack.set_bool(settings_pack::enable_upnp, true);
    pack.set_bool(settings_pack::enable_natpmp, true);
    pack.set_bool(settings_pack::enable_lsd, true);
    pack.set_bool(settings_pack::enable_dht, true);
    pack.set_int(settings_pack::dht_announce_interval, 30 * 60);
    pack.set_int(settings_pack::active_limit, 200);
    pack.set_int(settings_pack::active_downloads, 10);
    pack.set_int(settings_pack::active_seeds, 5);
    pack.set_int(settings_pack::connections_limit, 200);
    pack.set_str(settings_pack::user_agent, "iTorrentFlow/1.0");
    s->ses.apply_settings(std::move(pack));
    s->ses.add_dht_node(std::make_pair("router.bittorrent.com", 6881));
    s->ses.add_dht_node(std::make_pair("dht.transmissionbt.com", 6881));
    s->ses.add_dht_router(std::make_pair("router.bittorrent.com", 6881));
    s->ses.add_dht_router(std::make_pair("dht.transmissionbt.com", 6881));
    std::thread([s]() {
        while (true) {
            std::vector<alert *> alerts;
            s->ses.pop_alerts(&alerts);
            for (auto *a : alerts) {
                if (auto *ta = alert_cast<torrent_alert>(a)) {
                    auto ih = lt::to_hex(ta->handle.info_hash().to_string());
                    if (auto *sa = alert_cast<state_changed_alert>(a)) {
                        if (s->statusCb) {
                            auto st = ta->handle.status();
                            s->statusCb(ih.c_str(), st.progress, st.download_rate, st.upload_rate, st.num_peers, st.num_seeds, (int)st.state, "");
                        }
                    }
                    if (auto *pa = alert_cast<piece_finished_alert>(a)) {
                        if (s->pieceCb) s->pieceCb(ih.c_str(), pa->piece_index);
                    }
                    if (auto *fa = alert_cast<torrent_finished_alert>(a)) {
                        if (s->statusCb) {
                            auto st = ta->handle.status();
                            s->statusCb(ih.c_str(), 1.0, st.download_rate, st.upload_rate, st.num_peers, st.num_seeds, (int)st.state, "Completed");
                        }
                    }
                }
                if (auto *la = alert_cast<log_alert>(a)) {
                    if (s->logCb) s->logCb(la->message().c_str());
                }
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(200));
        }
    }).detach();
    return s;
}

void lt_session_destroy(LTSessionRef session) {
    auto *s = get_session(session);
    s->ses.pause();
    delete s;
}

void lt_session_set_listen_port(LTSessionRef session, int port) {
    auto *s = get_session(session);
    settings_pack pack; pack.set_int(settings_pack::listen_port, port);
    s->ses.apply_settings(std::move(pack));
}

void lt_session_set_max_connections(LTSessionRef session, int max) {
    auto *s = get_session(session);
    settings_pack pack; pack.set_int(settings_pack::connections_limit, max);
    s->ses.apply_settings(std::move(pack));
}

void lt_session_set_max_upload_rate(LTSessionRef session, int64_t bytesPerSec) {
    auto *s = get_session(session);
    settings_pack pack; pack.set_int(settings_pack::upload_rate_limit, (int)bytesPerSec);
    s->ses.apply_settings(std::move(pack));
}

void lt_session_set_max_download_rate(LTSessionRef session, int64_t bytesPerSec) {
    auto *s = get_session(session);
    settings_pack pack; pack.set_int(settings_pack::download_rate_limit, (int)bytesPerSec);
    s->ses.apply_settings(std::move(pack));
}

void lt_session_enable_dht(LTSessionRef session, bool enable) {
    auto *s = get_session(session);
    settings_pack pack; pack.set_bool(settings_pack::enable_dht, enable);
    s->ses.apply_settings(std::move(pack));
}

void lt_session_enable_lsd(LTSessionRef session, bool enable) {
    auto *s = get_session(session);
    settings_pack pack; pack.set_bool(settings_pack::enable_lsd, enable);
    s->ses.apply_settings(std::move(pack));
}

void lt_session_enable_upnp(LTSessionRef session, bool enable) {
    auto *s = get_session(session);
    settings_pack pack; pack.set_bool(settings_pack::enable_upnp, enable);
    s->ses.apply_settings(std::move(pack));
}

void lt_session_enable_natpmp(LTSessionRef session, bool enable) {
    auto *s = get_session(session);
    settings_pack pack; pack.set_bool(settings_pack::enable_natpmp, enable);
    s->ses.apply_settings(std::move(pack));
}

const char *lt_session_add_torrent(LTSessionRef session, const char *torrentData, int dataLength, const char *savePath, const char **trackers, int trackerCount) {
    auto *s = get_session(session);
    try {
        add_torrent_params params;
        params.save_path = savePath;
        std::string td(torrentData, dataLength);
        params.ti = std::make_shared<torrent_info>(td.data(), td.size());
        for (int i = 0; i < trackerCount; i++) params.trackers.push_back(trackers[i]);
        auto handle = s->ses.add_torrent(std::move(params));
        auto ih = lt::to_hex(handle.info_hash().to_string());
        s->handles[ih] = handle;
        handle.auto_managed(true); handle.resume();
        return strdup(ih.c_str());
    } catch (const std::exception &e) { return strdup(e.what()); }
}

const char *lt_session_add_magnet(LTSessionRef session, const char *magnetURI, const char *savePath) {
    auto *s = get_session(session);
    try {
        add_torrent_params params;
        params.save_path = savePath; params.url = magnetURI;
        auto handle = s->ses.add_torrent(std::move(params));
        auto ih = lt::to_hex(handle.info_hash().to_string());
        s->handles[ih] = handle;
        handle.auto_managed(true); handle.resume();
        return strdup(ih.c_str());
    } catch (const std::exception &e) { return strdup(e.what()); }
}

void lt_session_pause(LTSessionRef session, const char *infoHash) {
    auto it = get_session(session)->handles.find(infoHash);
    if (it != get_session(session)->handles.end()) { it->second.auto_managed(false); it->second.pause(); }
}

void lt_session_resume(LTSessionRef session, const char *infoHash) {
    auto it = get_session(session)->handles.find(infoHash);
    if (it != get_session(session)->handles.end()) { it->second.auto_managed(true); it->second.resume(); }
}

void lt_session_remove(LTSessionRef session, const char *infoHash, bool deleteFiles) {
    auto *s = get_session(session);
    auto it = s->handles.find(infoHash);
    if (it != s->handles.end()) { s->ses.remove_torrent(it->second, deleteFiles ? session::delete_files : session::none); s->handles.erase(it); }
}

void lt_session_set_file_priority(LTSessionRef session, const char *infoHash, int fileIndex, int priority) {
    auto it = get_session(session)->handles.find(infoHash);
    if (it != get_session(session)->handles.end()) {
        auto priorities = it->second.file_priorities();
        if (fileIndex >= 0 && fileIndex < (int)priorities.size()) { priorities[fileIndex] = (download_priority_t)priority; it->second.prioritize_files(priorities); }
    }
}

void lt_session_set_callbacks(LTSessionRef session, LTStatusCallback statusCb, LTPieceCallback pieceCb, LTLogCallback logCb) {
    auto *s = get_session(session); s->statusCb = statusCb; s->pieceCb = pieceCb; s->logCb = logCb;
}

void lt_session_add_tracker(LTSessionRef session, const char *infoHash, const char *trackerURL) {
    auto it = get_session(session)->handles.find(infoHash);
    if (it != get_session(session)->handles.end()) { it->second.add_tracker(announce_entry(trackerURL)); }
}

void lt_session_replace_trackers(LTSessionRef session, const char *infoHash, const char **trackers, int count) {
    auto it = get_session(session)->handles.find(infoHash);
    if (it != get_session(session)->handles.end()) {
        std::vector<announce_entry> entries;
        for (int i = 0; i < count; i++) entries.emplace_back(trackers[i]);
        it->second.replace_trackers(entries);
    }
}

void lt_session_add_dht_node(LTSessionRef session, const char *host, int port) {
    get_session(session)->ses.add_dht_node(std::make_pair(std::string(host), port));
}

void lt_session_add_dht_router(LTSessionRef session, const char *host, int port) {
    get_session(session)->ses.add_dht_router(std::make_pair(std::string(host), port));
}

void lt_session_pause_all(LTSessionRef session) { get_session(session)->ses.pause(); }
void lt_session_resume_all(LTSessionRef session) { get_session(session)->ses.resume(); }

#else

// Stub implementations — LibTorrent not available
struct lt_session_handle {
    LTStatusCallback statusCb;
    LTPieceCallback pieceCb;
    LTLogCallback logCb;
};

static lt_session_handle *get_session(LTSessionRef ref) { return ref; }

LTSessionRef lt_session_create(void) { return new lt_session_handle(); }
void lt_session_destroy(LTSessionRef session) { delete get_session(session); }
void lt_session_set_listen_port(LTSessionRef session, int port) {}
void lt_session_set_max_connections(LTSessionRef session, int max) {}
void lt_session_set_max_upload_rate(LTSessionRef session, int64_t bytesPerSec) {}
void lt_session_set_max_download_rate(LTSessionRef session, int64_t bytesPerSec) {}
void lt_session_enable_dht(LTSessionRef session, bool enable) {}
void lt_session_enable_lsd(LTSessionRef session, bool enable) {}
void lt_session_enable_upnp(LTSessionRef session, bool enable) {}
void lt_session_enable_natpmp(LTSessionRef session, bool enable) {}
const char *lt_session_add_torrent(LTSessionRef session, const char *torrentData, int dataLength, const char *savePath, const char **trackers, int trackerCount) { return strdup("LibTorrent not available"); }
const char *lt_session_add_magnet(LTSessionRef session, const char *magnetURI, const char *savePath) { return strdup("LibTorrent not available"); }
void lt_session_pause(LTSessionRef session, const char *infoHash) {}
void lt_session_resume(LTSessionRef session, const char *infoHash) {}
void lt_session_remove(LTSessionRef session, const char *infoHash, bool deleteFiles) {}
void lt_session_set_file_priority(LTSessionRef session, const char *infoHash, int fileIndex, int priority) {}
void lt_session_set_callbacks(LTSessionRef session, LTStatusCallback statusCb, LTPieceCallback pieceCb, LTLogCallback logCb) {}
void lt_session_add_tracker(LTSessionRef session, const char *infoHash, const char *trackerURL) {}
void lt_session_replace_trackers(LTSessionRef session, const char *infoHash, const char **trackers, int count) {}
void lt_session_add_dht_node(LTSessionRef session, const char *host, int port) {}
void lt_session_add_dht_router(LTSessionRef session, const char *host, int port) {}
void lt_session_pause_all(LTSessionRef session) {}
void lt_session_resume_all(LTSessionRef session) {}

#endif
