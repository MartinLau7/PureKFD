//
//  BrowseView.swift
//  purekfd
//
//  Created by Lrdsnow on 6/26/24.
//

import SwiftUI
import JASON
import NukeUI

struct BrowseView: View {
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var repoHandler: RepoHandler
    @State private var searchText: String = ""
    @State private var showErrorSheet = false
    @State private var selectedRepo: Repo? = nil
    @AppStorage("accentColor") private var accentColor: Color = Color(hex: "#D4A7FC")!
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.accentColor
                    .ignoresSafeArea(.all)
                    .opacity(0.07)
                ScrollView(.vertical) {
                    VStack {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Browse").font(.system(size: 36, weight: .bold)).minimumScaleFactor(0.8).lineLimit(1).foregroundColor(.accentColor)
                            }
                            Spacer()
                            Button(action: {
                                showTextInputPopup("Add Repo", "Enter URL", .URL, completion: { string in
                                    if let string = string,
                                       let url = URL(string: string) {
                                        repoHandler.addRepo(url, appData)
                                    }
                                })
                            }, label: {
                                Image(systemName: "plus").foregroundColor(.accentColor)
                            }).buttonStyle(.borderedProminent).tint(.accentColor.opacity(0.3)).cornerRadius(50).frame(height: 32)//.clipShape(.circle)
                        }.padding(.leading, 1)
                        // Search
                        HStack {
                            TextField("Search", text: $searchText)
                                .padding(.horizontal, 25)
                                .padding()
                                .autocorrectionDisabled()
                                .overlay(
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.accentColor.opacity(0.7))
                                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                            .padding(.leading, 15)
                                        
                                        if !searchText.isEmpty {
                                            Button(action: {
                                                self.searchText = ""
                                            }) {
                                                Image(systemName: "multiply.circle.fill")
                                                    .foregroundColor(.accentColor.opacity(0.7))
                                                    .padding(.trailing, 15)
                                            }
                                        }
                                    }
                                )
                        }.background(RoundedRectangle(cornerRadius: 25).foregroundColor(.accentColor.opacity(0.1)))
                        //
                        VStack {
                            if searchText == "" {
                                ForEach(appData.repos.sorted(by: { $0.name < $1.name }), id: \.fullURL) { repo in
                                    if repo.filtered != true {
                                        RepoListRowView(repo: repo, showErrorSheet: $showErrorSheet, selectedRepo: $selectedRepo)
                                    }
                                }
                                FilteredReposViewNavLink(showErrorSheet: $showErrorSheet, selectedRepo: $selectedRepo)
                            } else {
                                ForEach(appData.pkgs.filter({ $0.name.contains(searchText)}).sorted(by: { $0.name < $1.name }), id:\.bundleid) { tweak in
                                    TweakListRowView(tweak: tweak)
                                }
                            }
                        }.refreshable {
                            repoHandler.updateRepos(appData)
                        }
                    }.padding(.horizontal).padding(.bottom, 60)
                }.ios16padding().listStyle(.plain).navigationBarTitleDisplayMode(.inline).onAppear() {
                    updateInstalledTweaks(appData)
                    repoHandler.updateRepos(appData)
                }.refreshable {
                    repoHandler.updateRepos(appData)
                }.sheet(isPresented: $showErrorSheet) {
                    ErrorInfoPageView(pkg: .constant(nil), repo: $selectedRepo).accentColor(accentColor)
                }
            }
        }.navigationViewStyle(.stack)
    }
}

struct FilteredReposViewNavLink: View {
    @Binding var showErrorSheet: Bool
    @Binding var selectedRepo: Repo?
    
    @EnvironmentObject var appData: AppData
    
    var body: some View {
        let filteredRepos = Array(Set(appData.repos.filter( { $0.filtered == true } )))
        if filteredRepos.count > 0 {
            VStack {
                HStack {
                    NavigationLink(destination: {
                        ZStack {
                            Color.accentColor
                                .ignoresSafeArea(.all)
                                .opacity(0.07)
                            ScrollView(.vertical) {
                                VStack {
                                    ForEach(filteredRepos.sorted(by: { $0.name < $1.name }), id: \.fullURL) { repo in
                                        RepoListRowView(repo: repo, showErrorSheet: $showErrorSheet, selectedRepo: $selectedRepo)
                                    }
                                }.padding(.horizontal)
                            }
                        }
                    }, label: {
                        Text("\(filteredRepos.count) Filtered Repos")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.accentColor).font(.footnote)
                    })
                }.padding()
            }.background(RoundedRectangle(cornerRadius: 25).foregroundColor(.accentColor.opacity(0.1)))
        }
    }
}

struct RepoListRowView: View {
    let repo: Repo
    @Binding var showErrorSheet: Bool
    @Binding var selectedRepo: Repo?
    
    @State private var accent: Color? = nil
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var repoHandler: RepoHandler
    
    var body: some View {
        HStack {
            NavigationLink(destination: RepoView(repo: repo, bgColor: accent ?? repo.accentColor ?? .accentColor)) {
                HStack {
                    LazyImage(url: repo.iconURL) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .background(Color.black)
                                .onAppear() {
                                    if accent == nil,
                                       UserDefaults.standard.bool(forKey: "useAvgImageColors") {
                                        if let uiImage = state.imageContainer?.image,
                                           let accentColor = averageColor(from: uiImage) {
                                            accent = Color(accentColor.bright())
                                            appData.setRepoLiveAccent(accent, repo.url, repo.iconURL)
                                        }
                                    }
                                }
                        } else if state.error != nil {
                            appIconImage
                                .resizable()
                                .scaledToFill()
                        } else {
                            ProgressView()
                                .scaledToFit()
                        }
                    }.frame(width: 45, height: 45).cornerRadius(11).padding(.trailing, 3)
                    VStack(alignment: .leading) {
                        Text(repo.name).font(.title3.weight(.bold)).minimumScaleFactor(0.8).lineLimit(1).foregroundColor(accent ?? repo.accentColor ?? .accentColor)
                        Text(repo.description.uppercaseFirstLetter()).font(.subheadline).minimumScaleFactor(0.8).lineLimit(1).opacity(0.7).foregroundColor(accent ?? repo.accentColor ?? .accentColor)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(accent ?? repo.accentColor ?? .accentColor).font(.footnote)
                }
            }.padding()
        }.background(RoundedRectangle(cornerRadius: 25).foregroundColor((accent ?? repo.accentColor ?? .accentColor).opacity(0.1))).listRowSeparator(.hidden).onAppear() {
            accent = repo._liveAccent
        }.contextMenu {
            if let url = repo.prettyURL {
                Text(url).font(.footnote).minimumScaleFactor(0.5).lineLimit(1).opacity(0.5)
            }
            if repo.error != nil {
                Button(action: {
                    selectedRepo = repo
                    showErrorSheet = true
                }, label: {
                    HStack {
                        Text("Error Info")
                        Spacer()
                        Image(systemName: "exclamationmark.circle.fill")
                    }
                })
            }
            Button(action: {
                if let url = repo.fullURL {
                    let pasteboard = UIPasteboard.general
                    pasteboard.string = url.absoluteString
                }
            }, label: {
                HStack {
                    Text("Copy URL")
                    Spacer()
                    Image(systemName: "doc.on.clipboard")
                }
            })
            Button(role: .destructive, action: {
                if let url = repo.fullURL {
                    repoHandler.removeRepo(url, appData)
                }
            }, label: {
                HStack {
                    Text("Delete Repo")
                    Spacer()
                    Image(systemName: "trash")
                }
            })
        }
    }
}
