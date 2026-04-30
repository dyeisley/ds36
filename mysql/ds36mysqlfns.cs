
/*
 * DVD Store 3.6 MySQL Functions - ds2mysqlfns.cs
 *
 * Copyright (C) 2005 Dell, Inc. <dave_jaffe@dell.com> and <tmuirhead@vmware.com>
 *
 * Provides interface functions for DVD Store driver program ds2xdriver.cs
 * See ds2xdriver.cs for compilation and syntax
 *
 * Last Updated 6/27/05
 * Last updated 6/14/2010 by GSK
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA  */



using System;
using System.Data;
using MySql.Data.MySqlClient;
using System.Threading;
using System.Diagnostics;


namespace ds2xdriver
  {
  /// <summary>
  /// ds2mysqlfns.cs: DVD Store 3.6  MySql Functions
  /// </summary>
  public class ds2Interface
    {
    int ds2Interfaceid;
    MySqlConnection objConn;
    MySqlCommand Login, New_Customer, New_Member, Browse, BrowseReviews, GetReviews, New_Review, New_Helpfulness, Purchase;
    MySqlParameter cust_out_param, reviewid_out_param, helpfulnessid_out_param;
    //string conn_str = "Server=" +  Controller.target + ";User ID=web;Password=web;Database=DS2";
    //Changed by GSK (connection string will be initialized in new Overloaded constructor )
    string conn_str = "";
    string target_server_name;
    int target_store_number = 1; //Added to support Multiple stores - default is 1
//
//-------------------------------------------------------------------------------------------------
// 
    public ds2Interface(int ds2interfaceid)
      {
      ds2Interfaceid = ds2interfaceid;
      //Console.WriteLine("ds2Interface {0} created", ds2Interfaceid);
      }
//
//-------------------------------------------------------------------------------------------------
    //Added by GSK (Overloaded the constructor to handle scenario where Single instance of Driver program is driving load on multiple machines)
    public ds2Interface ( int ds2interfaceid , string target_name)
        {
        ds2Interfaceid = ds2interfaceid;
        target_server_name = target_name;
        conn_str = "Server=" + target_server_name + ";User ID=web;Password=web;Database=DS3";
        //Console.WriteLine("ds2Interface {0} created", ds2Interfaceid);
        }
//
//-------------------------------------------------------------------------------------------------
// 
    // (Overloaded constructor to support multiple stores within single DS3 instance)
    public ds2Interface(int ds2interfaceid, string target_name, int target_store)
    {
        ds2Interfaceid = ds2interfaceid;
        target_server_name = target_name;
        target_store_number = target_store;
        conn_str = "Server=" + target_server_name + ";User ID=web;Password=web;Database=DS3";
        //Console.WriteLine("ds2Interface {0} created", ds2Interfaceid);
    }
 
//
//-------------------------------------------------------------------------------------------------
//  
    public bool ds2connect()
      {
      try
        {
        objConn = new MySqlConnection(conn_str);
        objConn.Open();
        }
      catch (MySqlException e)
        {
        //Changed by GSK
        //Console.WriteLine("Thread {0}: error in connecting to database {1}: {2}",  Thread.CurrentThread.Name,
        //  Controller.target, e.Message);
        Console.WriteLine("Thread {0}: error in connecting to database {1}: {2}",  Thread.CurrentThread.Name,
          target_server_name , e.Message );
        return(false);
        }

      // Set up MySql stored procedure calls and associated parameters
      New_Customer = new MySqlCommand("NEW_CUSTOMER" + target_store_number, objConn);
      New_Customer.CommandType = CommandType.StoredProcedure; 
      New_Customer.Parameters.Add("username_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("password_in", MySqlDbType.VarChar, 50);    
      New_Customer.Parameters.Add("firstname_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("lastname_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("address1_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("address2_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("city_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("state_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("zip_in", MySqlDbType.Int32);
      New_Customer.Parameters.Add("country_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("region_in", MySqlDbType.Int32);
      New_Customer.Parameters.Add("email_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("phone_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("creditcardtype_in", MySqlDbType.Int32);
      New_Customer.Parameters.Add("creditcard_in", MySqlDbType.VarChar, 50);
      New_Customer.Parameters.Add("creditcardexpiration_in", MySqlDbType.VarChar, 50); 
      New_Customer.Parameters.Add("age_in", MySqlDbType.Byte);
      New_Customer.Parameters.Add("income_in", MySqlDbType.Int32);
      New_Customer.Parameters.Add("gender_in", MySqlDbType.VarChar, 1);
      cust_out_param = new MySqlParameter("customerid_out", MySqlDbType.Int32);
      cust_out_param.Direction = ParameterDirection.Output;
      cust_out_param.Value = 0;
      New_Customer.Parameters.Add(cust_out_param);

      New_Member = new MySqlCommand("NEW_MEMBER" + target_store_number, objConn);
      New_Member.CommandType = CommandType.StoredProcedure;
      New_Member.Parameters.Add("customerid_in", MySqlDbType.Int32);
      New_Member.Parameters.Add("membershiplevel_in", MySqlDbType.Int32);
      New_Member.Parameters.Add(cust_out_param);

      New_Review = new MySqlCommand("NEW_PROD_REVIEW" + target_store_number, objConn);
      New_Review.CommandType = CommandType.StoredProcedure;
      New_Review.Parameters.Add("prod_id_in", MySqlDbType.Int32);
      New_Review.Parameters.Add("stars_in", MySqlDbType.Int32);
      New_Review.Parameters.Add("customerid_in", MySqlDbType.Int32);
      New_Review.Parameters.Add("review_summary_in", MySqlDbType.VarChar, 50);
      New_Review.Parameters.Add("review_text_in", MySqlDbType.VarChar, 1000);
      reviewid_out_param = new MySqlParameter("review_id_out", MySqlDbType.Int32);
      reviewid_out_param.Direction = ParameterDirection.Output;
      reviewid_out_param.Value = 0;
      New_Review.Parameters.Add(reviewid_out_param);

      New_Helpfulness = new MySqlCommand("NEW_REVIEW_HELPFULNESS" + target_store_number, objConn);
      New_Helpfulness.CommandType = CommandType.StoredProcedure;
      New_Helpfulness.Parameters.Add("review_id_in", MySqlDbType.Int32);
      New_Helpfulness.Parameters.Add("customerid_in", MySqlDbType.Int32);
      New_Helpfulness.Parameters.Add("review_helpfulness_in", MySqlDbType.Int32);
      helpfulnessid_out_param = new MySqlParameter("review_helpfulness_id_out", MySqlDbType.Int32);
      helpfulnessid_out_param.Direction = ParameterDirection.Output;
      helpfulnessid_out_param.Value = 0;
      New_Helpfulness.Parameters.Add(helpfulnessid_out_param);

      return(true);
      } // end ds2connect()
 
//
//-------------------------------------------------------------------------------------------------
// 
    public bool ds2login(string username_in, string password_in, ref int customerid_out, ref int rows_returned,
      ref string[] title_out, ref string[] actor_out, ref string[] related_title_out, ref double rt)
      {
      rows_returned = 0;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        // Query 1: Get customer ID with parameterized query
        string query1 = "SELECT CUSTOMERID FROM DS3.CUSTOMERS" + target_store_number +
          " WHERE USERNAME=@username AND PASSWORD=@password";
        Login = new MySqlCommand(query1, objConn);
        Login.Parameters.AddWithValue("@username", username_in);
        Login.Parameters.AddWithValue("@password", password_in);

        using (MySqlDataReader Rdr = Login.ExecuteReader())
        {
          if (!Rdr.HasRows)  // No customer found
          {
            customerid_out = 0;
            return true;
          }
          Rdr.Read();
          customerid_out = Rdr.GetInt32(0);
        }

        // Query 2: Get product IDs from customer history with parameterized query
        string query2 = "SELECT PROD_ID FROM DS3.CUST_HIST" + target_store_number +
          " WHERE CUSTOMERID=@customerid ORDER BY ORDERID DESC LIMIT 10";
        Login = new MySqlCommand(query2, objConn);
        Login.Parameters.AddWithValue("@customerid", customerid_out);

        using (MySqlDataReader Rdr = Login.ExecuteReader())
        {
          if (!Rdr.HasRows)  // No previous order
          {
            //Console.WriteLine("No previous orders");
            return true;
          }

          int i_row = 0;
          while (Rdr.Read())
          {
            int prod_id = Rdr.GetInt32(0);

            // Use second connection for nested queries with parameterized queries
            using (MySqlConnection conn2 = new MySqlConnection(conn_str))
            {
              conn2.Open();

              // Query 3: Get title and actor
              string query3 = "SELECT TITLE, ACTOR FROM DS3.PRODUCTS" + target_store_number +
                " WHERE PROD_ID=@prod_id";
              using (MySqlCommand Login2 = new MySqlCommand(query3, conn2))
              {
                Login2.Parameters.AddWithValue("@prod_id", prod_id);
                using (MySqlDataReader Rdr2 = Login2.ExecuteReader())
                {
                  Rdr2.Read();
                  title_out[i_row] = Rdr2.GetString(0);
                  actor_out[i_row] = Rdr2.GetString(1);
                }
              }

              // Query 4: Get related title
              string query4 = "SELECT TITLE FROM DS3.PRODUCTS" + target_store_number +
                " WHERE PROD_ID=(SELECT COMMON_PROD_ID FROM DS3.PRODUCTS" + target_store_number +
                " WHERE PROD_ID=@prod_id)";
              using (MySqlCommand Login3 = new MySqlCommand(query4, conn2))
              {
                Login3.Parameters.AddWithValue("@prod_id", prod_id);
                related_title_out[i_row] = (string)Login3.ExecuteScalar();
              }
            }
            ++i_row;
          }
          rows_returned = i_row;
        }
        return true;
      }
      catch (MySqlException e)
      {
        Console.WriteLine("Thread {0}: Error in Login: {1}", Thread.CurrentThread.Name, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
      }  // end ds2login
//
//-------------------------------------------------------------------------------------------------
// 
    public bool ds2newcustomer(string username_in, string password_in, string firstname_in,
      string lastname_in, string address1_in, string address2_in, string city_in, string state_in,
      string zip_in, string country_in, string email_in, string phone_in, int creditcardtype_in,
      string creditcard_in, int ccexpmon_in, int ccexpyr_in, int age_in, int income_in,
      string gender_in, ref int customerid_out, ref double rt)
      {
      int region_in = (country_in == "US") ? 1:2;
      string creditcardexpiration_in = String.Format("{0:D4}/{1:D2}", ccexpyr_in, ccexpmon_in);

      New_Customer.Parameters["username_in"].Value = username_in;
      New_Customer.Parameters["password_in"].Value = password_in;
      New_Customer.Parameters["firstname_in"].Value = firstname_in;
      New_Customer.Parameters["lastname_in"].Value = lastname_in;
      New_Customer.Parameters["address1_in"].Value = address1_in;
      New_Customer.Parameters["address2_in"].Value = address2_in;
      New_Customer.Parameters["city_in"].Value = city_in;
      New_Customer.Parameters["state_in"].Value = state_in;
      New_Customer.Parameters["zip_in"].Value = (zip_in=="") ? 0 : Convert.ToInt32(zip_in);
      New_Customer.Parameters["country_in"].Value = country_in;
      New_Customer.Parameters["region_in"].Value = region_in;
      New_Customer.Parameters["email_in"].Value = email_in;
      New_Customer.Parameters["phone_in"].Value = phone_in;
      New_Customer.Parameters["creditcardtype_in"].Value = creditcardtype_in;
      New_Customer.Parameters["creditcard_in"].Value = creditcard_in;
      New_Customer.Parameters["creditcardexpiration_in"].Value = creditcardexpiration_in;
      New_Customer.Parameters["age_in"].Value = age_in;
      New_Customer.Parameters["income_in"].Value = income_in;
      New_Customer.Parameters["gender_in"].Value = gender_in;

//    Console.WriteLine("Thread {0}: Calling New_Customer w/username_in= {1}  region={2}  ccexp={3}",
//      Thread.CurrentThread.Name, username_in, region_in, creditcardexpiration_in);

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        New_Customer.ExecuteNonQuery();
        customerid_out = (int) cust_out_param.Value;
        return true;
      }
      catch (MySqlException e)
      {
        Console.WriteLine("Thread {0}: MySql Error {1} in New_Customer: {2}",
          Thread.CurrentThread.Name, e.Number, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
      } // end ds2newcustomer()

    //
    //-------------------------------------------------------------------------------------------------
    // 
    public bool ds2newmember(int customerid_in, int membershiplevel_in, ref int customerid_out, ref double rt)
    {
      New_Member.Parameters["customerid_in"].Value = customerid_in;
      New_Member.Parameters["membershiplevel_in"].Value = membershiplevel_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        New_Member.ExecuteNonQuery();
        customerid_out = (int)cust_out_param.Value;

//    Console.WriteLine("Thread {0}: New_Customer created w/username_in= {1}  region={2}  customerid={3}",
//      Thread.CurrentThread.Name, username_in, region_in, customerid_out);

        return true;
      }
      catch (MySqlException e)
      {
        Console.WriteLine("Thread {0}: MySql Error {1} in New_Member: {2}",
          Thread.CurrentThread.Name, e.Number, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    } // end ds2newmember()




//
//-------------------------------------------------------------------------------------------------
// 
    public bool ds2browse(string browse_type_in, string browse_category_in, string browse_actor_in,
      string browse_title_in, int batch_size_in, int search_depth_in, int customerid_out, ref int rows_returned,
      ref int[] prod_id_out, ref string[] title_out, ref string[] actor_out, ref decimal[] price_out,
      ref int[] special_out, ref int[] common_prod_id_out, ref double rt)
      {
      // Products table: PROD_ID INT, CATEGORY TINYINT, TITLE VARCHAR(50), ACTOR VARCHAR(50),
      //   PRICE DECIMAL(12,2), SPECIAL TINYINT, COMMON_PROD_ID INT
      int[] category_out = new int[GlobalConstants.MAX_ROWS];

      // Build parameterized query based on browse type
      string query;
      switch(browse_type_in)
        {
        case "title":
          query = "SELECT * FROM PRODUCTS" + target_store_number +
            " WHERE MATCH (TITLE) AGAINST (@search) LIMIT @batch_size";
          Browse = new MySqlCommand(query, objConn);
          Browse.Parameters.AddWithValue("@search", browse_title_in);
          Browse.Parameters.AddWithValue("@batch_size", batch_size_in);
          break;
        case "actor":
          query = "SELECT * FROM PRODUCTS" + target_store_number +
            " WHERE MATCH (ACTOR) AGAINST (@search) LIMIT @batch_size";
          Browse = new MySqlCommand(query, objConn);
          Browse.Parameters.AddWithValue("@search", browse_actor_in);
          Browse.Parameters.AddWithValue("@batch_size", batch_size_in);
          break;
        case "category":
          query = "SELECT * FROM PRODUCTS" + target_store_number +
            " WHERE CATEGORY=@category AND SPECIAL=1 LIMIT @batch_size";
          Browse = new MySqlCommand(query, objConn);
          Browse.Parameters.AddWithValue("@category", Convert.ToInt32(browse_category_in));
          Browse.Parameters.AddWithValue("@batch_size", batch_size_in);
          break;
        }

//    Console.WriteLine("Thread {0}: Calling Browse w/ browse_type= {1} batch_size_in= {2}  category= {3}" +
//      " title= {4}  actor= {5}", Thread.CurrentThread.Name, browse_type_in, batch_size_in, browse_category_in,
//      browse_title_in, browse_actor_in);

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        using (MySqlDataReader Rdr = Browse.ExecuteReader())
        {
          int i_row = 0;
          if (!Rdr.HasRows) // No rows returned
          {
            //Console.WriteLine("No DVDs Found");
          }
          else  // Rows returned
          {
            while (Rdr.Read())
            {
              prod_id_out[i_row] = Rdr.GetInt32(0);
              category_out[i_row] = Rdr.GetByte(1);
              title_out[i_row] = Rdr.GetString(2);
              actor_out[i_row] = Rdr.GetString(3);
              price_out[i_row] = Rdr.GetDecimal(4);
              special_out[i_row] = Rdr.GetByte(5);
              common_prod_id_out[i_row] = Rdr.GetInt32(6);
              ++i_row;
            }
          }
          rows_returned = i_row;
        }
        return true;
      }
      catch (MySqlException e)
      {
        Console.WriteLine("Thread {0}: Error in Browse: {1}", Thread.CurrentThread.Name, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
      } // end ds2browse()

    //
    //-------------------------------------------------------------------------------------------------
    // 

    public bool ds2browsereview(string browse_review_type_in, string get_review_category_in, string get_review_actor_in,
      string get_review_title_in, int batch_size_in, int search_depth_in, int customerid_out, ref int rows_returned,
      ref int[] prod_id_out, ref string[] title_out, ref string[] actor_out, ref int[] review_id_out,
      ref string[] review_date_out, ref int[] review_stars_out, ref int[] review_customerid_out,
      ref string[] review_summary_out, ref string[] review_text_out, ref int[] review_helpfulness_sum_out, ref double rt)
    {
        // Reviews Table: "REVIEW_ID" NUMBER,  "PROD_ID" NUMBER,  "REVIEW_DATE" DATE, "STARS" NUMBER,
        // "CUSTOMERID" NUMBER,  "REVIEW_SUMMARY" VARCHAR2(50 byte), "REVIEW_TEXT" VARCHAR2(1000 byte)

        // Build parameterized query based on review type
        string query;
        switch (browse_review_type_in)
        {
            case "actor":
                query = "SELECT T1.prod_id, T1.title, T1.actor, REVIEWS_HELPFULNESS" + target_store_number + ".REVIEW_ID, T1.review_date, T1.stars, " +
                    "T1.customerid, T1.review_summary, T1.review_text, SUM(helpfulness) AS totalhelp FROM REVIEWS_HELPFULNESS" + target_store_number + " " +
                    "INNER JOIN (SELECT TITLE, ACTOR, PRODUCTS" + target_store_number + ".PROD_ID, REVIEWS" + target_store_number + ".review_date, REVIEWS" + target_store_number + ".stars, " +
                    "REVIEWS" + target_store_number + ".review_id, REVIEWS" + target_store_number + ".customerid, REVIEWS" + target_store_number + ".review_summary, REVIEWS" + target_store_number + ".review_text " +
                    "FROM PRODUCTS" + target_store_number + " INNER JOIN REVIEWS" + target_store_number + " ON PRODUCTS" + target_store_number + ".prod_id = REVIEWS" + target_store_number + ".prod_id " +
                    "WHERE MATCH (ACTOR) AGAINST (@search) LIMIT @search_depth) " +
                    "AS T1 ON REVIEWS_HELPFULNESS" + target_store_number + ".REVIEW_ID = T1.review_id GROUP BY REVIEW_ID ORDER BY totalhelp DESC LIMIT @batch_size";
                BrowseReviews = new MySqlCommand(query, objConn);
                BrowseReviews.Parameters.AddWithValue("@search", get_review_actor_in);
                BrowseReviews.Parameters.AddWithValue("@search_depth", search_depth_in);
                BrowseReviews.Parameters.AddWithValue("@batch_size", batch_size_in);
                break;
            case "title":
                query = "SELECT T1.prod_id, T1.title, T1.actor, REVIEWS_HELPFULNESS" + target_store_number + ".REVIEW_ID, T1.review_date, T1.stars, " +
                    "T1.customerid, T1.review_summary, T1.review_text, SUM(helpfulness) AS totalhelp FROM REVIEWS_HELPFULNESS" + target_store_number + " " +
                    "INNER JOIN (SELECT TITLE, ACTOR, PRODUCTS" + target_store_number + ".PROD_ID, REVIEWS" + target_store_number + ".review_date, REVIEWS" + target_store_number + ".stars, " +
                    "REVIEWS" + target_store_number + ".review_id, REVIEWS" + target_store_number + ".customerid, REVIEWS" + target_store_number + ".review_summary, REVIEWS" + target_store_number + ".review_text " +
                    "FROM PRODUCTS" + target_store_number + " INNER JOIN REVIEWS" + target_store_number + " ON PRODUCTS" + target_store_number + ".prod_id = REVIEWS" + target_store_number + ".prod_id " +
                    "WHERE MATCH (TITLE) AGAINST (@search) LIMIT @search_depth) " +
                    "AS T1 ON REVIEWS_HELPFULNESS" + target_store_number + ".REVIEW_ID = T1.review_id GROUP BY REVIEW_ID ORDER BY totalhelp DESC LIMIT @batch_size";
                BrowseReviews = new MySqlCommand(query, objConn);
                BrowseReviews.Parameters.AddWithValue("@search", get_review_title_in);
                BrowseReviews.Parameters.AddWithValue("@search_depth", search_depth_in);
                BrowseReviews.Parameters.AddWithValue("@batch_size", batch_size_in);
                break;
        }

        //    Console.WriteLine("Thread {0}: Calling Browse w/ browse_type= {1}  batch_size_in= {2}  data_in= {3}",
        //      Thread.CurrentThread.Name, browse_type_in, batch_size_in, data_in);

        Stopwatch timer = Stopwatch.StartNew();

        try
        {
            using (MySqlDataReader Rdr = BrowseReviews.ExecuteReader())
            {
              int i_row = 0;
              while (Rdr.Read())
              {
                prod_id_out[i_row] = Rdr.GetInt32(0);
                title_out[i_row] = Rdr.GetString(1);
                actor_out[i_row] = Rdr.GetString(2);
                review_id_out[i_row] = Rdr.GetInt32(3);
                review_date_out[i_row] = Rdr.GetDateTime(4).ToString();
                review_stars_out[i_row] = Rdr.GetInt32(5);
                review_customerid_out[i_row] = Rdr.GetInt32(6);
                review_summary_out[i_row] = Rdr.GetString(7);
                review_text_out[i_row] = Rdr.GetString(8);
                review_helpfulness_sum_out[i_row] = Rdr.GetInt32(9);
                ++i_row;
              } // end while rdr.read()
              rows_returned = i_row;
            }
            return true;
        }
        catch (MySqlException e)
        {
            Console.WriteLine("Thread {0}: MySQL Error in Browse Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
            return false;
        }
        catch (System.Exception e)
        {
            Console.WriteLine("Thread {0}: System Error in Browse Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
            return false;
        }
        finally
        {
          rt = timer.Elapsed.TotalSeconds;
        }
    } // end ds2browsereview()

    //
    //-------------------------------------------------------------------------------------------------
    // 

    public bool ds2getreview(string get_review_type_in, int get_review_prod_in, int get_review_stars_in, int customerid_out, int batch_size_in, ref int rows_returned,
      ref int[] prod_id_out, ref int[] review_id_out, ref string[] review_date_out, ref int[] review_stars_out, ref int[] review_customerid_out,
      ref string[] review_summary_out, ref string[] review_text_out, ref int[] review_helpfulness_sum_out, ref double rt)
    {
        // Reviews Table: "REVIEW_ID" NUMBER,  "PROD_ID" NUMBER,  "REVIEW_DATE" DATE, "STARS" NUMBER,
        // "CUSTOMERID" NUMBER,  "REVIEW_SUMMARY" VARCHAR2(50 byte), "REVIEW_TEXT" VARCHAR2(1000 byte)

        // Build parameterized query based on review type
        string query;
        switch (get_review_type_in)
        {
            case "noorder":
                query = "SELECT REVIEWS" + target_store_number + ".review_id, REVIEWS" + target_store_number + ".prod_id, REVIEWS" + target_store_number + ".review_date, REVIEWS" + target_store_number + ".stars, " +
                    "REVIEWS" + target_store_number + ".customerid, REVIEWS" + target_store_number + ".review_summary, REVIEWS" + target_store_number + ".review_text, SUM(REVIEWS_HELPFULNESS" + target_store_number + ".helpfulness) " +
                    "AS total FROM REVIEWS" + target_store_number + " INNER JOIN REVIEWS_HELPFULNESS" + target_store_number + " ON REVIEWS" + target_store_number + ".review_id=REVIEWS_HELPFULNESS" + target_store_number + ".review_id " +
                    "WHERE PROD_ID=@prod_id GROUP BY REVIEWS" + target_store_number + ".review_id ORDER BY total DESC";
                GetReviews = new MySqlCommand(query, objConn);
                GetReviews.Parameters.AddWithValue("@prod_id", get_review_prod_in);
                break;
            case "star":
                query = "SELECT REVIEWS" + target_store_number + ".review_id, REVIEWS" + target_store_number + ".prod_id, REVIEWS" + target_store_number + ".review_date, REVIEWS" + target_store_number + ".stars, " +
                    "REVIEWS" + target_store_number + ".customerid, REVIEWS" + target_store_number + ".review_summary, REVIEWS" + target_store_number + ".review_text, SUM(REVIEWS_HELPFULNESS" + target_store_number + ".helpfulness) " +
                    "AS total FROM REVIEWS" + target_store_number + " INNER JOIN REVIEWS_HELPFULNESS" + target_store_number + " ON REVIEWS" + target_store_number + ".review_id=REVIEWS_HELPFULNESS" + target_store_number + ".review_id " +
                    "WHERE PROD_ID=@prod_id AND STARS=@stars GROUP BY REVIEWS" + target_store_number + ".review_id ORDER BY total DESC";
                GetReviews = new MySqlCommand(query, objConn);
                GetReviews.Parameters.AddWithValue("@prod_id", get_review_prod_in);
                GetReviews.Parameters.AddWithValue("@stars", get_review_stars_in);
                break;
            case "date":
                query = "SELECT REVIEWS" + target_store_number + ".review_id, REVIEWS" + target_store_number + ".prod_id, REVIEWS" + target_store_number + ".review_date, REVIEWS" + target_store_number + ".stars, " +
                    "REVIEWS" + target_store_number + ".customerid, REVIEWS" + target_store_number + ".review_summary, REVIEWS" + target_store_number + ".review_text, SUM(REVIEWS_HELPFULNESS" + target_store_number + ".helpfulness) " +
                    "AS total FROM REVIEWS" + target_store_number + " INNER JOIN REVIEWS_HELPFULNESS" + target_store_number + " ON REVIEWS" + target_store_number + ".review_id=REVIEWS_HELPFULNESS" + target_store_number + ".review_id " +
                    "WHERE PROD_ID=@prod_id GROUP BY REVIEWS" + target_store_number + ".review_id ORDER BY REVIEW_DATE DESC";
                GetReviews = new MySqlCommand(query, objConn);
                GetReviews.Parameters.AddWithValue("@prod_id", get_review_prod_in);
                break;
        }

        Stopwatch timer = Stopwatch.StartNew();

        try
        {
            using (MySqlDataReader Rdr = GetReviews.ExecuteReader())
            {
              int i_row = 0;
              while (Rdr.Read())
              {
                review_id_out[i_row] = Rdr.GetInt32(0);
                prod_id_out[i_row] = Rdr.GetInt32(1);
                review_date_out[i_row] = Rdr.GetDateTime(2).ToString();
                review_stars_out[i_row] = Rdr.GetInt32(3);
                review_customerid_out[i_row] = Rdr.GetInt32(4);
                review_summary_out[i_row] = Rdr.GetString(5);
                review_text_out[i_row] = Rdr.GetString(6);
                review_helpfulness_sum_out[i_row] = Rdr.GetInt32(7);
                ++i_row;
              } // end while rdr.read()
              rows_returned = i_row;
            }
            return true;
        }
        catch (MySqlException e)
        {
            Console.WriteLine("Thread {0}: MySQL Error in Get Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
            return false;
        }
        catch (System.Exception e)
        {
            Console.WriteLine("Thread {0}: System Error in Get Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
            return false;
        }
        finally
        {
          rt = timer.Elapsed.TotalSeconds;
        }
    } // end ds2getreview()

    //
    //-------------------------------------------------------------------------------------------------
    // 
    public bool ds2newreview(int new_review_prod_id_in, int new_review_stars_in, int new_review_customerid_in,
            string new_review_summary_in, string new_review_text_in, ref int newreviewid_out, ref double rt)
    {
      New_Review.Parameters["prod_id_in"].Value = new_review_prod_id_in;
      New_Review.Parameters["stars_in"].Value = new_review_stars_in;
      New_Review.Parameters["customerid_in"].Value = new_review_customerid_in;
      New_Review.Parameters["review_summary_in"].Value = new_review_summary_in;
      New_Review.Parameters["review_text_in"].Value = new_review_text_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        New_Review.ExecuteNonQuery();
        newreviewid_out = (int)reviewid_out_param.Value;
        return true;
      }
      catch (MySqlException e)
      {
        Console.WriteLine("Thread {0}: MySql Error {1} in New_Review: {2}",
          Thread.CurrentThread.Name, e.Number, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    } // end ds2newreview()



    //
    //-------------------------------------------------------------------------------------------------
    // 
    public bool ds2newreviewhelpfulness(int reviewid_in, int customerid_in, int reviewhelpfulness_in, ref int reviewhelpfulnessid_out, ref double rt)
    {
      New_Helpfulness.Parameters["review_id_in"].Value = reviewid_in;
      New_Helpfulness.Parameters["customerid_in"].Value = customerid_in;
      New_Helpfulness.Parameters["review_helpfulness_in"].Value = reviewhelpfulness_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        New_Helpfulness.ExecuteNonQuery();
        reviewhelpfulnessid_out = (int)helpfulnessid_out_param.Value;
        return true;
      }
      catch (MySqlException e)
      {
        Console.WriteLine("Thread {0}: MySql Error {1} in New_Helpfulness: {2}",
          Thread.CurrentThread.Name, e.Number, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    } // end ds2newreviewhelpfulness()



//
//-------------------------------------------------------------------------------------------------
// 
    public bool ds2purchase(int cart_items, int[] prod_id_in, int[] qty_in, int customerid_out,
      ref int neworderid_out, ref bool IsRollback, ref double rt)
      {
      int j;
      bool success = false;

      // Find total cost of purchase with parameterized query
      Decimal netamount_in = 0;
      string cost_query = "SELECT PROD_ID, PRICE FROM PRODUCTS" + target_store_number + " WHERE PROD_ID IN (";
      for (int i=0; i<cart_items; i++)
      {
        if (i > 0) cost_query += ",";
        cost_query += "@prod" + i;
      }
      cost_query += ")";

      Purchase = new MySqlCommand(cost_query, objConn);
      for (int i=0; i<cart_items; i++)
      {
        Purchase.Parameters.AddWithValue("@prod" + i, prod_id_in[i]);
      }

      using (MySqlDataReader Rdr = Purchase.ExecuteReader())
      {
        while (Rdr.Read())
        {
          j = 0;
          int prod_id = Rdr.GetInt32(0);
          while (prod_id_in[j] != prod_id) ++j; // Find which product was returned
          netamount_in = netamount_in + qty_in[j] * Rdr.GetDecimal(1);
          //Console.WriteLine(j + " " + prod_id + " " + Rdr.GetDecimal(1));
        }
      }

      Decimal taxamount_in =  (Decimal) 0.0825 * netamount_in;
      Decimal totalamount_in = netamount_in + taxamount_in;

      // Insert new order into ORDERS table
      string currentdate = DateTime.Today.ToString("yyyy'-'MM'-'dd");

//    Console.WriteLine("Thread {0}: Calling Purchase w/ customerid = {1}  number_items= {2}",
//      Thread.CurrentThread.Name, customerid_out, cart_items);

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        MySqlTransaction trans = objConn.BeginTransaction(IsolationLevel.RepeatableRead);

        // Parameterized INSERT for order
        string order_query = "INSERT INTO DS3.ORDERS" + target_store_number +
          " (ORDERDATE, CUSTOMERID, NETAMOUNT, TAX, TOTALAMOUNT) VALUES (@date, @customerid, @netamount, @tax, @total)";
        Purchase = new MySqlCommand(order_query, objConn, trans);
        Purchase.Parameters.AddWithValue("@date", currentdate);
        Purchase.Parameters.AddWithValue("@customerid", customerid_out);
        Purchase.Parameters.AddWithValue("@netamount", netamount_in);
        Purchase.Parameters.AddWithValue("@tax", taxamount_in);
        Purchase.Parameters.AddWithValue("@total", totalamount_in);
        Purchase.ExecuteNonQuery();

        Purchase = new MySqlCommand("SELECT LAST_INSERT_ID()", objConn);
        neworderid_out = Convert.ToInt32(Purchase.ExecuteScalar().ToString());
//      Console.WriteLine("Thread {0}: Purchase: neworderid_out= {1}", Thread.CurrentThread.Name, neworderid_out);

        if (neworderid_out > 0) success = true;

        // Process each item with parameterized queries
        for (int i=0; i<cart_items; i++)
        {
          // Get current inventory
          string inv_query = "SELECT QUAN_IN_STOCK, SALES FROM DS3.INVENTORY" + target_store_number + " WHERE PROD_ID=@prod_id";
          Purchase = new MySqlCommand(inv_query, objConn);
          Purchase.Parameters.AddWithValue("@prod_id", prod_id_in[i]);

          int curr_quan, curr_sales;
          using (MySqlDataReader Rdr = Purchase.ExecuteReader())
          {
            Rdr.Read();
            curr_quan = Rdr.GetInt32(0);
            curr_sales = Rdr.GetInt32(1);
          }

          int new_quan = curr_quan - qty_in[i];
          int new_sales = curr_sales + qty_in[i];

          if (new_quan < 0)
          {
            //Console.WriteLine("Insufficient quantity for product " + prod_id_in[i]);
            success = false;
          }
          else
          {
            // Update inventory with parameterized query
            string upd_query = "UPDATE DS3.INVENTORY" + target_store_number +
              " SET QUAN_IN_STOCK=@new_quan, SALES=@new_sales WHERE PROD_ID=@prod_id";
            Purchase = new MySqlCommand(upd_query, objConn, trans);
            Purchase.Parameters.AddWithValue("@new_quan", new_quan);
            Purchase.Parameters.AddWithValue("@new_sales", new_sales);
            Purchase.Parameters.AddWithValue("@prod_id", prod_id_in[i]);
            Purchase.ExecuteNonQuery();

            // Insert orderline with parameterized query
            string orderline_query = "INSERT INTO DS3.ORDERLINES" + target_store_number +
              " (ORDERLINEID, ORDERID, PROD_ID, QUANTITY, ORDERDATE) VALUES (@lineid, @orderid, @prod_id, @qty, @date)";
            Purchase = new MySqlCommand(orderline_query, objConn, trans);
            Purchase.Parameters.AddWithValue("@lineid", i+1);
            Purchase.Parameters.AddWithValue("@orderid", neworderid_out);
            Purchase.Parameters.AddWithValue("@prod_id", prod_id_in[i]);
            Purchase.Parameters.AddWithValue("@qty", qty_in[i]);
            Purchase.Parameters.AddWithValue("@date", currentdate);
            Purchase.ExecuteNonQuery();

            // Insert cust_hist with parameterized query
            string custhist_query = "INSERT INTO DS3.CUST_HIST" + target_store_number +
              " (CUSTOMERID, ORDERID, PROD_ID) VALUES (@customerid, @orderid, @prod_id)";
            Purchase = new MySqlCommand(custhist_query, objConn, trans);
            Purchase.Parameters.AddWithValue("@customerid", customerid_out);
            Purchase.Parameters.AddWithValue("@orderid", neworderid_out);
            Purchase.Parameters.AddWithValue("@prod_id", prod_id_in[i]);
            Purchase.ExecuteNonQuery();
          }
        } // End of for loop

        if (success) trans.Commit();
        else trans.Rollback();

        if (!success)
        {
          IsRollback = true;
//        Console.WriteLine("Thread {0}: Purchase: Insufficient stock for order {1} - order not processed",
//          Thread.CurrentThread.Name, neworderid_out);
          neworderid_out = 0;
        }

        return true;
      }
      catch (MySqlException e)
      {
        Console.WriteLine("Thread {0}: MySql Error {1} in Purchase: {2}",
          Thread.CurrentThread.Name, e.Number, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
      } // end ds2purchase()

//
//-------------------------------------------------------------------------------------------------
//
    public bool ds2newproduct(int new_category_in, string new_title_in, string new_actor_in, decimal new_price_in, int new_stock_in, ref int newproduct_id, ref double rt)
    {
      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        // Insert new product into PRODUCTS table with parameterized query
        string product_query = "INSERT INTO DS3.PRODUCTS" + target_store_number +
          " (CATEGORY, TITLE, ACTOR, PRICE, SPECIAL, COMMON_PROD_ID, MEMBERSHIP_ITEM) " +
          "VALUES (@category, @title, @actor, @price, 0, 0, 0)";

        MySqlCommand product_cmd = new MySqlCommand(product_query, objConn);
        product_cmd.Parameters.AddWithValue("@category", new_category_in);
        product_cmd.Parameters.AddWithValue("@title", new_title_in);
        product_cmd.Parameters.AddWithValue("@actor", new_actor_in);
        product_cmd.Parameters.AddWithValue("@price", new_price_in);
        product_cmd.ExecuteNonQuery();

        // Get the new product ID
        MySqlCommand id_cmd = new MySqlCommand("SELECT LAST_INSERT_ID()", objConn);
        newproduct_id = Convert.ToInt32(id_cmd.ExecuteScalar());

        // Update COMMON_PROD_ID to match PROD_ID
        string update_query = "UPDATE DS3.PRODUCTS" + target_store_number +
          " SET COMMON_PROD_ID=@prod_id WHERE PROD_ID=@prod_id";
        MySqlCommand update_cmd = new MySqlCommand(update_query, objConn);
        update_cmd.Parameters.AddWithValue("@prod_id", newproduct_id);
        update_cmd.ExecuteNonQuery();

        // Insert inventory record with parameterized query
        string inventory_query = "INSERT INTO DS3.INVENTORY" + target_store_number +
          " (PROD_ID, QUAN_IN_STOCK, SALES) VALUES (@prod_id, @stock, 0)";
        MySqlCommand inventory_cmd = new MySqlCommand(inventory_query, objConn);
        inventory_cmd.Parameters.AddWithValue("@prod_id", newproduct_id);
        inventory_cmd.Parameters.AddWithValue("@stock", new_stock_in);
        inventory_cmd.ExecuteNonQuery();

        return true;
      }
      catch (MySqlException e)
      {
        Console.WriteLine("Thread {0}: MySql Error {1} in New_Product: {2}", Thread.CurrentThread.Name, e.Number, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    }

//
//-------------------------------------------------------------------------------------------------
// Manager Thread Methods
//-------------------------------------------------------------------------------------------------
//
    public int RemoveReviewByProduct(int prodId, int batchSize)
    {
        try
        {
            MySqlCommand cmd = new MySqlCommand($"DS3.RemoveReviewByProduct{target_store_number}", objConn)
            {
                CommandType = System.Data.CommandType.StoredProcedure
            };
            cmd.Parameters.AddWithValue("p_prod_id", prodId);
            cmd.Parameters.AddWithValue("p_batch_size", batchSize);

            return cmd.ExecuteNonQuery();
        }
        catch (Exception e)
        {
            Console.WriteLine($"Thread {Thread.CurrentThread.Name}: RemoveReviewByProduct error: {e.Message}");
            return 0;
        }
    }

//
//-------------------------------------------------------------------------------------------------
//
    public int RemoveUnhelpfulReviews(int batchSize)
    {
        try
        {
            MySqlCommand cmd = new MySqlCommand($"DS3.RemoveUnhelpfulReviews{target_store_number}", objConn)
            {
                CommandType = System.Data.CommandType.StoredProcedure
            };
            cmd.Parameters.AddWithValue("p_batch_size", batchSize);

            return cmd.ExecuteNonQuery();
        }
        catch (Exception e)
        {
            Console.WriteLine($"Thread {Thread.CurrentThread.Name}: RemoveUnhelpfulReviews error: {e.Message}");
            return 0;
        }
    }

//
//-------------------------------------------------------------------------------------------------
//
    public int AdjustPrices(int prodId)
    {
        try
        {
            MySqlCommand cmd = new MySqlCommand($"DS3.AdjustPrices{target_store_number}", objConn)
            {
                CommandType = System.Data.CommandType.StoredProcedure
            };
            cmd.Parameters.AddWithValue("p_prod_id", prodId);

            return cmd.ExecuteNonQuery();
        }
        catch (Exception e)
        {
            Console.WriteLine($"Thread {Thread.CurrentThread.Name}: AdjustPrices error: {e.Message}");
            return 0;
        }
    }

//
//-------------------------------------------------------------------------------------------------
//
    public int MarkSpecials(int prodId)
    {
        try
        {
            MySqlCommand cmd = new MySqlCommand($"DS3.MarkSpecials{target_store_number}", objConn)
            {
                CommandType = System.Data.CommandType.StoredProcedure
            };
            cmd.Parameters.AddWithValue("p_prod_id", prodId);

            return cmd.ExecuteNonQuery();
        }
        catch (Exception e)
        {
            Console.WriteLine($"Thread {Thread.CurrentThread.Name}: MarkSpecials error: {e.Message}");
            return 0;
        }
    }

//
//-------------------------------------------------------------------------------------------------
//
    public bool ds2close()
      {
      objConn.Close();
      return(true);
      } // end ds2close()
    } // end Class ds2Interface
  } // end namespace ds2xdriver
  
        
