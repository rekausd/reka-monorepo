declare module "klip-sdk" {
  export namespace prepare {
    export function auth(opts: { bappName: string }): Promise<{ request_key: string }>;
  }
  export function getResult(requestKey: string): Promise<any>;
}
