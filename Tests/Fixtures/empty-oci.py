"""Generate an empty, non-runnable OCI image for a loopback registry push test."""
import hashlib,io,json,sys,tarfile
archive,reference=sys.argv[1:]
blobs={}
def blob(value):
 data=json.dumps(value,separators=(',',':')).encode();digest=hashlib.sha256(data).hexdigest();blobs[digest]=data
 return {'digest':'sha256:'+digest,'size':len(data)}
config=blob({'architecture':'arm64','os':'linux','config':{},'rootfs':{'type':'layers','diff_ids':[]}})
manifest=blob({'schemaVersion':2,'mediaType':'application/vnd.oci.image.manifest.v1+json','config':dict(config,mediaType='application/vnd.oci.image.config.v1+json'),'layers':[]})
index={'schemaVersion':2,'manifests':[dict(manifest,mediaType='application/vnd.oci.image.manifest.v1+json',annotations={'org.opencontainers.image.ref.name':reference},platform={'os':'linux','architecture':'arm64'})]}
with tarfile.open(archive,'w') as tar:
 entries={'oci-layout':b'{"imageLayoutVersion":"1.0.0"}','index.json':json.dumps(index).encode()}
 entries.update({'blobs/sha256/'+digest:data for digest,data in blobs.items()})
 for name,data in entries.items():
  info=tarfile.TarInfo(name);info.size=len(data);info.mode=0o600;tar.addfile(info,io.BytesIO(data))
