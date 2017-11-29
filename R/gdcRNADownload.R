##' @title Download RNA data in GDC
##' @description Download gene expression quantification and isoform expression quantification data from GDC 
##'   either by providing the manifest file or by the API method developed in \pkg{TCGAbiolinks} package
##' @param manifest menifest file that is downloaded from the GDC cart. If provided, files whose UUIDs are in the manifest file 
##'   will be downloaded via gdc-client, otherwise, \code{project} and \code{data.type} arguments should be provided to download 
##'   data by the API method implemented in the \pkg{TCGAbiolinks} package. Default is \code{NULL}
##' @param project.id project id in GDC
##' @param data.type one of \code{'RNAseq'} and \code{'miRNAs'}
##' @param directory the folder to save downloaded files. Default is \code{'Data'}
##' @param write.manifest logical, whether to write out the manifest file
##' @export
##' @author Ruidong Li and Han Qu
gdcRNADownload <- function(manifest=NULL, project.id, data.type, directory='Data',
                           write.manifest=FALSE) {
  
  if (! is.null(manifest)) {
    manifestDownloadFun(manifest=manifest,directory=directory)
    
  } else {
    
    url <- gdcGetURL(project.id=project.id, data.type=data.type)
    manifest <- read.table(paste(url, '&return_type=manifest', sep=''), header=T, stringsAsFactors=F)
    
    systime <- gsub(' ', 'T', Sys.time())
    systime <- gsub(':', '-', systime)
    
    manifile <- paste(project.id, data.type, 'gdc_manifest', systime, 'txt', sep='.')
    write.table(manifest, file=manifile, row.names=F, sep='\t', quote=F)
    
    manifestDownloadFun(manifest=manifile,directory=directory)
    
    if (write.manifest == FALSE) {
      invisible(file.remove(manifile))
    }
  }
}



###
downloadClientFun <- function(os) {
  if (os == 'Linux') {
    adress <- 'https://gdc.cancer.gov/system/files/authenticated%20user/0/gdc-client_v1.3.0_Ubuntu14.04_x64.zip'
    download.file(adress, destfile = './gdc-client_v1.3.0_Ubuntu14.04_x64.zip')
    unzip('./gdc-client_v1.3.0_Ubuntu14.04_x64.zip', unzip='unzip')
    
  } else if ( os== 'Windows') {
    adress <- 'https://gdc.cancer.gov/system/files/authenticated%20user/0/gdc-client_v1.3.0_Windows_x64.zip'
    download.file(adress, destfile = './gdc-client_v1.3.0_Windows_x64.zip')
    unzip('./gdc-client_v1.3.0_Windows_x64.zip', unzip='unzip')
    
  } else if (os == 'Darwin') {
    adress <- 'https://gdc.cancer.gov/system/files/authenticated%20user/0/gdc-client_v1.3.0_OSX_x64.zip'
    download.file(adress, destfile = './gdc-client_v1.3.0_OSX_x64.zip')
    unzip('./gdc-client_v1.3.0_OSX_x64.zip', unzip='unzip')
  }
}


###
manifestDownloadFun <- function(manifest=manifest,directory) {
  
  ### download gdc-client
  if (! file.exists('gdc-client')) {
    downloadClientFun(Sys.info()[1])
  }
  
  manifestDa <- read.table(manifest, sep='\t', header=T, stringsAsFactors = F)
  ex <- manifestDa$filename %in% dir(paste(directory, dir(directory), sep='/'))
  nonex <- ! ex
  numFiles <- sum(ex)
  
  if(numFiles > 0) {
    message (paste('Already exists', numFiles, 'files !', sep=' '))
    
    if (sum(nonex) > 0 ) {
      message (paste('Download the other', sum(nonex), 'files !', sep=' '))
      
      manifestDa <- manifestDa[nonex,]
      manifest <- paste(manifestDa$id, collapse =' ')
      system(paste('./gdc-client download ', manifest, sep=''))
    } else {
      return(invisible())
    }
    
    
  } else {
    system(paste('./gdc-client download -m ', manifest, sep=''))
  }

  
  #### move to the directory
  files <- manifestDa$id
  if (directory == 'Data') {
    if (! dir.exists('Data')) {
      dir.create('Data')
    }
  } else {
    if (! dir.exists(directory)) {
      dir.create(directory)
    }
  }
  
  file.move(files, directory)
  
}


###
file.move <- function(files, directory) {
  file.copy(from=files, to=directory, recursive = TRUE)
  unlink(files, recursive=TRUE)
}


##############
gdcGetURL <- function(project.id, data.type) {
  urlAPI <- 'https://api.gdc.cancer.gov/files?'
  
  if (data.type=='RNAseq') {
    data.category <- 'Transcriptome Profiling'
    data.type <- 'Gene Expression Quantification'
    workflow.type <- 'HTSeq - Counts'
  } else if (data.type=='miRNAs') {
    data.category <- 'Transcriptome Profiling'
    data.type <- 'Isoform Expression Quantification'
    workflow.type <- 'BCGSC miRNA Profiling'
  } else if (data.type=='Clinical') {
    data.category <- 'Clinical'
    data.type <- 'Clinical Supplement'
    workflow.type <- NA
  }
  
  project <- paste('{"op":"in","content":{"field":"cases.project.project_id","value":["', project.id, '"]}}', sep='')
  dataCategory <- paste('{"op":"in","content":{"field":"files.data_category","value":"', data.category, '"}}', sep='')
  dataType <- paste('{"op":"in","content":{"field":"files.data_type","value":"', data.type, '"}}', sep='')
  workflowType <- paste('{"op":"in","content":{"field":"files.analysis.workflow_type","value":"', workflow.type, '"}}', sep='')
  
  
  if (is.na(workflow.type)) {
    content <- paste(project, dataCategory, dataType, sep=',')
  } else {
    content <- paste(project, dataCategory, dataType, workflowType, sep=',')
  }
  
  filters <- paste('filters=',URLencode(paste('{"op":"and","content":[', content, ']}', sep='')),sep='')
  
  expand <- paste('analysis', 'analysis.input_files', 'associated_entities',
                  'cases', 'cases.diagnoses','cases.diagnoses.treatments', 
                  'cases.demographic', 'cases.project', 'cases.samples', 'cases.samples.portions', 
                  'cases.samples.portions.analytes', 'cases.samples.portions.analytes.aliquots',
                  'cases.samples.portions.slides', sep=',')
  
  expand <- paste('expand=', expand, sep='')
  
  payload <- paste(filters, 'pretty=true', 'format=JSON', 'size=10000', expand, sep='&')
  url <- paste(urlAPI, payload, sep='')
  
  return (url)
}


